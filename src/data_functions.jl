#using Gallium
#using DataFrames

export monthly_to_quarterly
export compute_recovery_of_employment_at_given_recovery_of_output

"""
    month_to_quarter(date)

Returns the date corresponding to the first day of the quarter enclosing date

# Examples
```jldoctest
julia> Date(1990, 1, 1) == RED.month_to_quarter(Date(1990, 2, 1))
true
julia> Date(1990, 1, 1) == RED.month_to_quarter(Date(1990, 1, 1))
true
julia> Date(1990, 1, 1) == RED.month_to_quarter(Date(1990, 2, 25))
true
```
"""
function month_to_quarter(date::Date)
    new_month = 1 + 3 * floor((Dates.month(date) - 1) / 3)
    return Date(Dates.year(date), new_month, 1)
end


""" 
    monthly_to_quarterly(monthly_df)

Aggregates a monthly data frame to the quarterly frequency. The data frame should have a :DATE column.

# Examples
```jldoctest
julia> monthly = convert(DataFrame, hcat(collect([Dates.Date(1990, m, 1) for m in 1:3]), [1; 2; 3]));

julia> rename!(monthly, :x1 => :DATE);

julia> rename!(monthly, :x2 => :value);

julia> quarterly = monthly_to_quarterly(monthly, :value);

julia> quarterly[:value][1]
2.0

julia> length(quarterly[:value])
1
```
"""
function monthly_to_quarterly(monthly::DataFrame, column::Symbol)

    # quarter months: 1, 4, 7, 10
    quarter_months = collect(1:3:10)
    
    # Deep copy the data frame
    monthly_copy = deepcopy(monthly)
    
    # Drop initial rows until it starts on a quarter
    while !in(Dates.month(monthly_copy[:DATE][1]), quarter_months)

        # Verify that something is left to pop
        @assert 1 <= length(monthly_copy[:DATE])

        monthly_copy = monthly_copy[2:end, :]
    end
    
    # Drop end rows until it finishes before a quarter
    while !in(Dates.month(monthly_copy[:DATE][end]), 2 + quarter_months)
	monthly_copy = monthly_copy[1:end-1, :]
    end
    
    # Change month of each date to the nearest quarter
    monthly_copy[:DATE] = month_to_quarter.(monthly_copy[:DATE])

    # Split-apply-combine
    quarterly = by(monthly_copy, :DATE, df -> mean(df[column]))

    # Rename
    rename!(quarterly, :x1 => column)

    return quarterly
    
end


"""
    nber_string_to_date(date_string; quarter_not_month = false)

Convert NBER date to Julia Date

# Examples
```jldoctest
julia> Dates.Date(1860, 10, 1) == RED.nber_string_to_date("October 1860(III)")
true
julia> Dates.Date(2007, 12, 1) == RED.nber_string_to_date("December 2007 (IV)")
true
julia> Dates.Date(2007, 10, 1) == RED.nber_string_to_date("December 2007 (IV)", quarter_not_month = true)
true
julia> Dates.Date(1948, 10, 1) == RED.nber_string_to_date("November 1948(IV)", quarter_not_month = true)
true
```
"""
function nber_string_to_date(date_string::String; quarter_not_month::Bool = false)

    # Build dictionary for converting quarters into months:
    quarters_to_month = Dict("I" => 1, "II" => 4, "III" => 7, "IV" => 10);
    
    # Regular expression for date in the format [Month Year(Quarter)]
    date_regex = r"(^[A-Z][a-z]*) ?(\d{4}) ?\((I*V?)\)";
    
    year = parse(Int, replace(date_string, date_regex, s"\2"))

    if (quarter_not_month)
	quarter_string = replace(date_string, date_regex, s"\3")
	month = quarters_to_month[quarter_string]
    else
	month_string = replace(date_string, date_regex, s"\1")
	month = Dates.monthname_to_value(month_string, Dates.LOCALES["english"])
    end

    return Dates.Date(year, month, 1)
end

"""
    string_to_date_quarter(date_string)

Convert NBER date string to Julia Date and align it to a quarter

"""
function string_to_date_quarter(date_string)
    return string_to_date(date_string, quarter_not_month = true)
end


"""
    get_loading_below(; below, above, targete)

Calculate the loading to place on two time periods to compute a synthetic
time period at a given value with linear interpolation

# Examples
```jldoctest
julia> RED.get_loading_below(below = 4, above = 6, target = 5)
0.5
julia> RED.get_loading_below(below = 2, above = 10, target = 4)
0.75
```
"""
function get_loading_below(; below::Number = nothing,
			   above::Number = nothing,
			   target::Number = nothing)
    
    # Verify that all are positive
    @assert 0 < above
    @assert 0 < below
    @assert 0 < target
    
    # Verify the ordering: below < recovery < above
    @assert below < target
    @assert target < above
    
    return (above - target) / (above - below)
end


"""
    get_unique_index(vector, element):

Get the index in the vector that equals element and assert it exists and is unique

# Examples
```jldoctest
julia> vector = [4; 5; 6];

julia> RED.get_unique_index(5, vector)
2

julia> RED.get_unique_index(2, vector)
ERROR: AssertionError: 1 == length(index_results)
```
"""
function get_unique_index(element, vector)
    index_results = find(x -> x == element, vector)
    @assert 1 == length(index_results)
    return index_results[1]
end

"""
Compute the recovery of employment at a given recovery of output

# Examples
```jldoctest
julia> dates = collect([Dates.Date(2001, m, 1) for m in 1:3:10]);
julia> assert False
julia> gdp = [1; 0; 1; 2];

julia> emp = [1; 0; 0.5; 1];

julia> gdp_df = DataFrame(DATE = dates, log = gdp)

julia> emp_df = DataFrame(DATE = dates, log = emp)

julia> recovery_target_log = 1.5;

julia> peaks = [Dates.Date(2001, 1, 1)];

julia> troughs = [Dates.Date(2001, 4, 1)];

julia> compute_recovery_of_employment_at_given_recovery_of_output(gdp_df = gdp_df, emp_df = emp_df, recovery_target_log = recovery_target_log, peaks = peaks, troughs = troughs)

```
"""
function compute_recovery_of_employment_at_given_recovery_of_output(; gdp_df::DataFrame = nothing,
                                                                    emp_df::DataFrame = nothing,
                                                                    recovery_target_log::Number = nothing,
                                                                    peaks::Array{Date} = nothing,
                                                                    troughs::Array{Date} = nothing)

    # Initialize at empty
    recoveries = DataFrame(DATE = Date[],
                           recovery = Number[])

    # Iterate on peaks
    for peak_tuple in enumerate(peaks)
	i_peak = peak_tuple[1]
	peak = peak_tuple[2]

	# Focus on post-war period
	if 1945 >= Dates.year(peak)
	    continue
	end

	# Get the corresponding trough, right after this peak
	trough = nothing
	for trough_local in troughs_quarters
	    if (trough_local > peak)
		trough = trough_local
		break
	    end
	end

	# Get the index in the GDP DataFrame
	gdp_trough_index = get_unique_index(trough, gdp_df[:DATE])

	# Find the bracket of time by which GDP has recovered by x%, so with
	# interpolation we'll find the time by which it has recovered exactly by 5%
	index_after = gdp_df[:DATE] .> gdp_df[:DATE][gdp_trough_index]
	index_recovery = gdp_df[:log] .>= gdp_df[:log][gdp_trough_index] + recovery_target_log
	gdp_recovery_above_indices = find(index_after .& index_recovery)
	@assert 1 <= length(gdp_recovery_above_indices)
	gdp_recovery_above_index = gdp_recovery_above_indices[1]
	gdp_recovery_above_date = gdp_df[:DATE][gdp_recovery_above_index]
        
	# Skip if this recovery was cut short, i.e. if the date for the recovery index happens
	# after the next peak
	if (length(peaks_quarters) > i_peak)
	    if (peaks_quarters[i_peak + 1] < gdp_df[:DATE][gdp_recovery_above_index])
		continue
	    end
	end

	# Amount of recovery at this index
	gdp_recovery_above = gdp_df[:log][gdp_recovery_above_index] - gdp_df[:log][gdp_trough_index]

	# Same shortcuts for right below the recovery point
	gdp_recovery_below_index = gdp_recovery_above_index - 1
	gdp_recovery_below = gdp_df[:log][gdp_recovery_below_index] - gdp_df[:log][gdp_trough_index]

	# Calculate loadings on the GDP recovery below and above, so the
	# interpolation gives 5% exactly
	# println(peak, "-", trough, " - ", " - ", gdp_recovery_below, " - ", gdp_recovery_above)
	loading_below = get_loading_below(below = gdp_recovery_below, above = gdp_recovery_above, target = recovery_target_log)

	@assert isapprox(recovery_target_log,
			 loading_below * gdp_recovery_below + (1 - loading_below) * gdp_recovery_above,
			 atol = eps(recovery))
        
	# Get the index for employment at the trough and at recovery
	emp_trough_index = get_unique_index(trough, emp_df[:DATE])
	emp_recovery_above_index = get_unique_index(gdp_recovery_above_date, emp_df[:DATE])
	emp_recovery_below_index = emp_recovery_above_index - 1
	emp_recovery_below = emp_df[:log][emp_recovery_below_index] - emp_df[:log][emp_trough_index]
	emp_recovery_above = emp_df[:log][emp_recovery_above_index] - emp_df[:log][emp_trough_index]

	emp_recovery = loading_below * emp_recovery_below + (1 - loading_below) * emp_recovery_above

        # Append to recoveries DataFrame
        push!(recoveries, trough, emp_recovery)

    end
    return recoveries
end

    

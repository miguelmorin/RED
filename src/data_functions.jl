# Packages for debugging
#using Gallium
#using DataFrames

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

Aggregates a monthly data frame to the quarterly frequency. The data frame should have a :DATE column
and a :value column.

# Examples
```jldoctest
julia> monthly = convert(DataFrame, hcat(collect([Dates.Date(1990, m, 1) for m in 1:3]), [1; 2; 3]));

julia> rename!(monthly, :x1 => :DATE);

julia> rename!(monthly, :x2 => :value);

julia> quarterly = RED.monthly_to_quarterly(monthly);

julia> quarterly[:value][1]
2.0

julia> length(quarterly[:value])
1
```
"""
function monthly_to_quarterly(monthly::DataFrame)

    @assert :DATE == names(monthly)[1] ("Expected first column to be :DATE, not " * string(names(monthly)[1]))
    column = names(monthly)[2]
    
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
Convert NBER date string to Julia Date and align it to a quarter

"""
function nber_string_to_date_quarter(date_string)
    return nber_string_to_date(date_string, quarter_not_month = true)
end

"""
Convert NBER date string to Julia Date and align it to a quarter

"""
function nber_string_to_date_month(date_string)
    return nber_string_to_date(date_string, quarter_not_month = false)
end

function filepath_hash_to_df(; filepath = nothing, expected_hash = nothing)
    # Check the hash
    found_hash = hash(readstring(filepath))
    @assert expected_hash == found_hash ("Filepath " * filepath * " has a different hash.\nExpected: " * string(expected_hash) * "\nFound: " * string(found_hash))

    # Start loading data at the second line if it's CSV, otherwise at the first line
    csv_file = endswith(filepath, ".csv")

    # Load CSV
    df = CSV.read(filepath, datarow = csv_file ? 2 : 1)

    # Convert filename to symbol, without the extension
    series_symbol = Symbol(replace(filepath,  r"(^.*/)([^.]*)(\..*$)", s"\2"))
    
    if csv_file
        # Verify names
        @assert [:DATE, series_symbol] == names(df) ("Unexpected names: " * string(names(df)))
        # CSV.read already converts the date column to Date, and verify that here
	@assert Date == typeof(df[:DATE][1])
    else
	# Change name from :Column1 to :value
	rename!(df, :Column1 => series_symbol)
    end

    return df
end

function load_data_from_list(; list_filenames_hashes::Dict{String, Integer} = nothing,
                             verbose = false)

    # Global variables
    global data_folder
    
    # Initialize data for scope in the function
    quarterly_data = nothing
    monthly_data = nothing
    
    for (i_filename, filename) in enumerate(keys(list_filenames_hashes))
        filepath = joinpath(data_folder, filename)
        df = filepath_hash_to_df(filepath = filepath, expected_hash = list_filenames_hashes[filename])

        if verbose
            println("loaded " * filepath)
        end

        # Check if this dataframe is monthly, then convert it
        monthly_df = nothing
        quarterly_df = nothing
        if (convert(Integer, Dates.value(Dates.Month(df[:DATE][2]))) == convert(Integer, Dates.value(Dates.Month(df[:DATE][1]))) + 1)
            quarterly_df = monthly_to_quarterly(df)
            monthly_df = df
        else
            quarterly_df = df
        end

        if (nothing == quarterly_data)
            # If this is the first file, add to data frame
            quarterly_data = df
        else
            # Merge to existing data frame, with outer join to keep all dates
            quarterly_data = join(quarterly_data, quarterly_df, on = :DATE, kind = :outer)
        end

        # Add to the monthly data frame?
        if nothing != monthly_df
            if (nothing == monthly_data)
                monthly_data = monthly_df
            else
                monthly_data = join(monthly_data, monthly_df, on = :DATE)
            end
        end
    end
    return Dict(:quarterly => quarterly_data, :monthly => monthly_data)
end

function load_nber_cycles(; nber_data_hashes::Dict{String, Integer} = nothing, data_folder::String = nothing)

    # Initialize
    cycles = Dict{Symbol, Array{Dates.Date}}()
    
    for (i_filename, filename) in enumerate(keys(nber_data_hashes))
        filepath = joinpath(data_folder, filename)
        df = filepath_hash_to_df(filepath = filepath, expected_hash = nber_data_hashes[filename])

        @assert 1 == length(names(df))
        name = names(df)[1]
        cycles[Symbol(string(name) * "_month")] = map(nber_string_to_date_month, df[name])
        cycles[Symbol(string(name) * "_quarter")] = map(nber_string_to_date_quarter, df[name])
    end
    return cycles

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
    @assert 1 == length(index_results) "Expected 1 match for " * string(element) * ", found " * string(length(index_results))
    return index_results[1]
end

"""
Compute the recovery of employment at a given recovery of output

# Examples
```jldoctest
julia> dates = collect([Dates.Date(2001, m, 1) for m in 1:3:10]);

julia> gdp = [1; 0; 1; 2];

julia> emp = [1; 0; 0.5; 1];

julia> df = DataFrame(DATE = dates, gdp_log = gdp, emp_log = emp);

julia> recovery_target_log = 1.5;

julia> peaks = [Dates.Date(2001, 1, 1)];

julia> troughs = [Dates.Date(2001, 4, 1)];

julia> RED.compute_recovery_of_employment_at_given_recovery_of_output(df = df, gdp_log_column = :gdp_log, emp_log_column = :emp_log, recovery_target_log = recovery_target_log, peaks = peaks, troughs = troughs)
1×2 DataFrames.DataFrame
│ Row │ year │ recovery │
├─────┼──────┼──────────┤
│ 1   │ 2001 │ 0.75     │
```
"""
function compute_recovery_of_employment_at_given_recovery_of_output(; df::DataFrame = nothing,
                                                                    gdp_log_column::Symbol = nothing,
                                                                    emp_column::Symbol = nothing,
                                                                    employment_is_rate = nothing,
                                                                    recovery_target_log::Number = nothing,
                                                                    peaks::Array{Date} = nothing,
                                                                    troughs::Array{Date} = nothing)

    # Initialize a DataFrame at empty
    recoveries = DataFrame(year = Integer[],
                           recovery = Float64[])

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
	for trough_local in troughs
	    if (trough_local > peak)
		trough = trough_local
		break
	    end
	end

	# Get the index in the GDP DataFrame
	trough_index = get_unique_index(trough, df[:DATE])

        # Check if GDP and employment are defined at the trough
        if ismissing(df[gdp_log_column][trough_index]) | ismissing(df[emp_column][trough_index])
            continue
        end

	# Find the bracket of time by which GDP has recovered by x%, so with
	# interpolation we'll find the time by which it has recovered exactly by 5%
	index_after = df[:DATE] .> df[:DATE][trough_index]
	index_recovery = df[gdp_log_column] .>= df[gdp_log_column][trough_index] + recovery_target_log
	gdp_recovery_above_indices = find(index_after .& index_recovery)
	@assert 1 <= length(gdp_recovery_above_indices)
	recovery_above_index = gdp_recovery_above_indices[1]
        
	# Skip if this recovery was cut short, i.e. if the date for the recovery index happens
	# after the next peak
	if (length(peaks) > i_peak)
	    if (peaks[i_peak + 1] < df[:DATE][recovery_above_index])
		continue
	    end
	end

	# Amount of recovery at this index
	gdp_recovery_above = df[gdp_log_column][recovery_above_index] - df[gdp_log_column][trough_index]

	# Same shortcuts for right below the recovery point
	recovery_below_index = recovery_above_index - 1
	gdp_recovery_below = df[gdp_log_column][recovery_below_index] - df[gdp_log_column][trough_index]

	# Calculate loadings on the GDP recovery below and above, so the
	# interpolation gives 5% exactly
	# println(peak, "-", trough, " - ", " - ", gdp_recovery_below, " - ", gdp_recovery_above)
	loading_below = get_loading_below(below = gdp_recovery_below, above = gdp_recovery_above, target = recovery_target_log)

	@assert isapprox(recovery_target_log,
			 loading_below * gdp_recovery_below + (1 - loading_below) * gdp_recovery_above,
			 atol = eps(recovery_target_log))
        
	# Get the index for employment at the trough and at recovery
	emp_recovery_below = df[emp_column][recovery_below_index] - df[emp_column][trough_index]
	emp_recovery_above = df[emp_column][recovery_above_index] - df[emp_column][trough_index]

	emp_recovery = loading_below * emp_recovery_below + (1 - loading_below) * emp_recovery_above

        if !employment_is_rate
            # Convert back to percentage
            emp_recovery = 100 * (exp(emp_recovery) - 1)
        end

        # Append to recoveries DataFrame
        recoveries = vcat(recoveries, DataFrame(year = Dates.year(peak), recovery = emp_recovery))

    end
    return recoveries
end

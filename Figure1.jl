
# Import RED module with functions

include("src/RED.jl")

# Use this and other modules
using RED
using DataFrames


"""
 Download the following data from the St Louis Fed, or use the ones saved locally in CSV:
 - [GDP](https://fred.stlouisfed.org/series/GDPC1)
 - [payroll emploment](https://fred.stlouisfed.org/series/PAYEMS)

 Copy-past the NBER peaks and troughs from [[http://www.nber.org/cycles.html][NBER business cycle dating]], or use the ones saved locally in TXT:
 - NBER_peaks.txt
 - NBER_troughs.txt
"""

data_folder = "data";

# Verify hashes of files, otherwise things may change inadvertently
list_filenames = Dict("GDPC1.csv" => 18406736056617138266,
		      "PAYEMS.csv" => 13819066176910162213,
		      "NBER_peaks.txt" => 4901701600789099464,
		      "NBER_troughs.txt" => 14025698590750588114);
data = Dict();
for filename in keys(list_filenames)
    filepath = joinpath(data_folder, filename)
    #println(filename)
    #println(hash(readstring(filepath)))
    @assert list_filenames[filename] == hash(readstring(filepath))

    # Start loading data at the second line if it's CSV, otherwise at the first line
    csv_file = endswith(filename, ".csv")

    # Load CSV
    df = CSV.read(filepath, datarow = csv_file ? 2 : 1)

    # CSV.read already converts the date column to Date, and verify that here
    if csv_file
	@assert Date == typeof(df[:DATE][1])
    else
	# Change name from :Column1 to :value
	rename!(df, :Column1 => :value)
    end

    # Convert to symbol without the dot
    symbol_name = replace(filename,  r"(^[^.]*)(\..*$)", s"\1")
    println("loaded " * symbol_name)

    # Add to data dictionary
    data[Symbol(symbol_name)] = df
end

# Aggregate monthly to quarterly
data[:PAYEMS_Q] = monthly_to_quarterly(data[:PAYEMS], :PAYEMS);
println("converted employment to quarterly")

# This block converts NBER dates in text-form into Julia dates for NBER peaks and troughs.
# TODO: finish here

peaks_months = map(nber_string_to_date, data[:NBER_peaks][:value])
troughs_months = map(nber_string_to_date, data[:NBER_troughs][:value])
peaks_quarters = map(nber_string_to_date_quarter, data[:NBER_peaks][:value])
troughs_quarters = map(nber_string_to_date_quarter, data[:NBER_troughs][:value])


recovery_target_log = log(1 + 0.05);

# Shortcut to GDP DataFrame with logs
gdp_df = deepcopy(data[:GDPC1]);
gdp_df[:log] = log.(gdp_df[:GDPC1]);

# Shortcut to employment DataFrame with logs
emp_df = deepcopy(data[:PAYEMS_Q]);
emp_df[:log] = log.(emp_df[:PAYEMS]);

recoveries = compute_recovery_of_employment_at_given_recovery_of_output(gdp_df = gdp_df,
									emp_df = emp_df,
									recovery_target_log = recovery_target_log,
									peaks = peaks_quarters,
									troughs = troughs_quarters)
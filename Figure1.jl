
workspace()

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

# Problem: why is load_data not defined??
@assert false
data = load_data(list_filenames)

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

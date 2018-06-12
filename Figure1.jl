
# Packages for plotting
using Gadfly
using Cairo

# Include my package
include("src/RED.jl")

# Use this package to revise source code in the same REPL session, as in this answer:
# https://stackoverflow.com/questions/25028873/how-do-i-reload-a-module-in-an-active-julia-session-after-an-edit/50816280#50816280
using Revise

# Import the package functions into Main, accessible with RED.[name]
import RED

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
list_filenames = Dict{String, Integer}("GDPC1.csv" => 18406736056617138266,
		                       "PAYEMS.csv" => 13819066176910162213,
                                       "LNS12000001.csv" => 16424143318742204293,
                                       "LNS12000002.csv" => 15988222264250118898,
		                       "NBER_peaks.txt" => 4901701600789099464,
		                       "NBER_troughs.txt" => 14025698590750588114);

data = RED.load_data_from_list(list_filenames = list_filenames, data_folder = data_folder)

# Aggregate monthly to quarterly
data[:PAYEMS_Q] = RED.monthly_to_quarterly(data[:PAYEMS]);
data[:emp_men_Q] = RED.monthly_to_quarterly(data[:LNS12000001])
data[:emp_women_Q] = RED.monthly_to_quarterly(data[:LNS12000002])
println("converted employment to quarterly")

# This block converts NBER dates in text-form into Julia dates for NBER peaks and troughs.
# TODO: finish here

peaks_months = map(RED.nber_string_to_date, data[:NBER_peaks][:value])
troughs_months = map(RED.nber_string_to_date, data[:NBER_troughs][:value])
peaks_quarters = map(RED.nber_string_to_date_quarter, data[:NBER_peaks][:value])
troughs_quarters = map(RED.nber_string_to_date_quarter, data[:NBER_troughs][:value])


recovery_target_log = log(1 + 0.05);

# Shortcut to GDP DataFrame with logs
gdp_df = deepcopy(data[:GDPC1]);
gdp_df[:log] = log.(gdp_df[:value]);

# Shortcut to employment DataFrame with logs
#emp_df = deepcopy(data[:PAYEMS_Q]);

emp = :PAYEMS_Q
emp_df = deepcopy(data[emp])
emp_df[:log] = log.(emp_df[:value]);

recoveries = RED.compute_recovery_of_employment_at_given_recovery_of_output(gdp_df = gdp_df,
									emp_df = emp_df,
									recovery_target_log = recovery_target_log,
									peaks = peaks_quarters,
									troughs = troughs_quarters)

# Compute average and standard error before 1990:
before_1990 = find(recoveries[:year] .< 1990)
after_1990 = find(recoveries[:year] .>= 1990)

interval_factor = 1.96

before_average = mean(recoveries[:recovery][before_1990])
before_sd = std(recoveries[:recovery][before_1990]) / sqrt(length(before_1990))

before_plus = before_average + interval_factor * before_sd
before_minus = before_average - interval_factor * before_sd

after_average = mean(recoveries[:recovery][after_1990])
after_sd = std(recoveries[:recovery][after_1990]) / sqrt(length(after_1990))

after_plus = after_average + interval_factor * after_sd
after_minus = after_average - interval_factor * after_sd

# Verify that I got the intervals right
@assert isapprox(2 * interval_factor * before_sd, before_plus - before_minus)
@assert isapprox(2 * interval_factor * after_sd, after_plus - after_minus)


#p =
plot(recoveries,
     x = 1,
     y = 2,
     Geom.bar,
     Scale.y_continuous(minvalue = min(before_minus, after_minus), maxvalue = max(before_plus, after_plus)),
     #Scale.x_discrete(levels = recoveries[:year]),
     Theme(bar_highlight = colorant"dark grey"),
     intercept = [0,
                  before_average, before_plus, before_minus,
                  after_average, after_plus, after_minus],
     slope = [0, 0, 0, 0, 0, 0, 0],
     Geom.abline(color = ["black", "green", "green", "green", "blue", "blue", "blue"],
                 style = [:solid, :solid, :dash, :dash, :solid, :dash, :dash]))

#draw(PDF("Figure1.pdf", 800px, 400px), p)

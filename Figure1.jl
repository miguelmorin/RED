
# Packages for plotting
using Gadfly
using Cairo

# Package for debugging
using Gallium

# Packages also required by RED
using DataFrames

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
 - and other series from their code, e.g. https://fred.stlouisfed.org/series/LNS12000002 for women's employment

 Copy-paste the NBER peaks and troughs from [[http://www.nber.org/cycles.html][NBER business cycle dating]], or use the ones saved locally in TXT:
 - NBER_peaks.txt
 - NBER_troughs.txt
"""

data_folder = "data";

# Verify hashes of files, otherwise things may change inadvertently
monthly_data_hashes = Dict{String, Integer}("PAYEMS.csv" => 13819066176910162213,
                                            "LNS12000001.csv" => 16424143318742204293,
                                            "LNS12000002.csv" => 15988222264250118898,
                                            "GDPC1.csv" => 18406736056617138266,
                                            "CE16OV.csv" => 4591378615148281314)

# Load monthly data
quarterly_data = RED.load_quarterly_data_from_list(list_filenames_hashes = monthly_data_hashes,
                                         data_folder = data_folder)

# Load NBER peaks and troughs
nber_data_hashes = Dict{String, Integer}("NBER_peaks.txt" => 4901701600789099464,
		                          "NBER_troughs.txt" => 14025698590750588114);

# This block converts NBER dates in text-form into Julia dates for NBER peaks and troughs.
nber_cycles = RED.load_nber_cycles(nber_data_hashes = nber_data_hashes, data_folder = data_folder)

recovery_target_log = log(1 + 0.05);

gdp_symbol = :GDPC1
emp_symbol = :PAYEMS

gdp_log_symbol = Symbol(string(gdp_symbol) * "_log")
emp_log_symbol = Symbol(string(emp_symbol) * "_log")

# Add columns with the log of these
quarterly_data[gdp_log_symbol] = log.(quarterly_data[gdp_symbol])
quarterly_data[emp_log_symbol] = log.(quarterly_data[emp_symbol])

# Compute recoveries
recoveries = RED.compute_recovery_of_employment_at_given_recovery_of_output(df = quarterly_data,
									    gdp_log_column = gdp_log_symbol,
                                                                            emp_log_column = emp_log_symbol,
									    recovery_target_log = recovery_target_log,
									    peaks = nber_cycles[:NBER_peaks],
									    troughs = nber_cycles[:NBER_troughs])

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

println(emp_symbol)

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
                 style = [:solid, :solid, :dash, :dash, :solid, :dash, :dash]),
     Guide.ylabel("Employment recovery for given recovery of output (%)", orientation = :vertical),
     Guide.xlabel("Peak year"),
     style(major_label_font_size = 10pt))

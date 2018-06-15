"""
 Download the following data from the St Louis Fed, or use the ones saved locally in CSV:
 - [GDP](https://fred.stlouisfed.org/series/GDPC1)
 - [payroll emploment](https://fred.stlouisfed.org/series/PAYEMS)
 - and other series from their code, e.g. https://fred.stlouisfed.org/series/LNS12000002 for women's employment

 Copy-paste the NBER peaks and troughs from [[http://www.nber.org/cycles.html][NBER business cycle dating]], or use the ones saved locally in TXT:
 - NBER_peaks.txt
 - NBER_troughs.txt
"""
function Figure1(; gdp_symbol = :GDPC1, emp_symbol = :PAYEMS, recovery_percent = 0.05, filepath = nothing, verbose = false)
    data_folder = "data";

    # Verify hashes of files, otherwise things may change inadvertently
    monthly_data_hashes = Dict{String, Integer}("PAYEMS.csv" => 13819066176910162213,
                                                "LNS12000001.csv" => 16424143318742204293,
                                                "LNS12000002.csv" => 15988222264250118898,
                                                "GDPC1.csv" => 18406736056617138266,
                                                "CE16OV.csv" => 4591378615148281314)

    # Load monthly data
    quarterly_data = RED.load_quarterly_data_from_list(list_filenames_hashes = monthly_data_hashes,
                                                       data_folder = data_folder,
                                                       verbose = verbose)

    # Load NBER peaks and troughs
    nber_data_hashes = Dict{String, Integer}("NBER_peaks.txt" => 4901701600789099464,
		                             "NBER_troughs.txt" => 14025698590750588114);

    # This block converts NBER dates in text-form into Julia dates for NBER peaks and troughs.
    nber_cycles = RED.load_nber_cycles(nber_data_hashes = nber_data_hashes, data_folder = data_folder)

    recovery_target_log = log(1 + recovery_percent);

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

    # Indices before and after 1990
    before_1990 = find(recoveries[:year] .< 1990)
    after_1990 = find(recoveries[:year] .>= 1990)

    # Linear regression to get the mean and its standard error
    before_fit = fit(LinearModel, @formula(recovery ~ year), recoveries)

    before_avg = coef(before_fit)[1]

    # before_std = 

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

    filepath_with_extension = filepath * ".png"
    if true
        # Version with Gadfly
        
        p = plot(x = recoveries[:year],
             y = recoveries[:recovery],
             Geom.bar,
             Scale.x_discrete,
             Scale.y_continuous(minvalue = min(before_minus, after_minus), maxvalue = max(before_plus, after_plus)),
             yintercept=[0,
                         before_average, before_plus, before_minus,
                         after_average, after_plus, after_minus],
             Geom.hline(color = ["black", "green", "green", "green", "blue", "blue", "blue"],
                        style = [:solid, :solid, :dash, :dash, :solid, :dash, :dash]),
             Guide.ylabel("Employment recovery for given recovery of output (%)", orientation = :vertical),
             Guide.xlabel("Peak year"),
             Theme(bar_highlight = colorant"dark grey",
                   bar_spacing = 2mm,
                   major_label_font_size = 10pt),
             Guide.title("Recovery for series " * string(emp_symbol)))
        draw(PNG(filepath_with_extension, 800px, 400px), p)
    else
        # Version with Plots.jl
        gr()
        
        ylim_upper = max(max(before_plus, after_plus), maximum(recoveries[:recovery]))
        ylim_lower = min(min(before_minus, before_plus), minimum(recoveries[:recovery]))
        margin = 0.05 * ylim_upper
        ylim_upper += margin
        ylim_lower -= margin


        p = plot([0,
              before_average, before_plus, before_minus,
              after_average, after_plus, after_minus],
             seriestype = [:hline, :hline, :hline, :hline, :hline, :hline, :hline])

        bar!(map(string, recoveries[:year]),
             recoveries[:recovery],
             legend = false,
             ylims = (ylim_lower, ylim_upper),
             seriestype = [:bar, :hline]
             )
        savefig(filepath_with_extension)
    end
return filepath_with_extension
end

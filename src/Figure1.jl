"""
 Download the following data from the St Louis Fed, or use the ones saved locally in CSV:
 - [GDP](https://fred.stlouisfed.org/series/GDPC1)
 - [payroll emploment](https://fred.stlouisfed.org/series/PAYEMS)
 - and other series from their code, e.g. https://fred.stlouisfed.org/series/LNS12000002 for women's employment

 Copy-paste the NBER peaks and troughs from [[http://www.nber.org/cycles.html][NBER business cycle dating]], or use the ones saved locally in TXT:
 - NBER_peaks.txt
 - NBER_troughs.txt
"""
function Figure1(; gdp_symbol::Symbol = :GDPC1,
                 emp_symbol::Symbol = :PAYEMS,
                 recovery_percent::Integer = 5,
                 filepath::String = nothing,
                 verbose::Bool = false)

    # Verify hashes of files, otherwise things may change inadvertently
    data_hashes = Dict{String, Integer}("PAYEMS.csv" => 13819066176910162213,
                                        "LNS12000001.csv" => 16424143318742204293,
                                        "LNS12000002.csv" => 15988222264250118898,
                                        "GDPC1.csv" => 18406736056617138266,
                                        "CE16OV.csv" => 4591378615148281314,
                                        "USGOOD.csv" => 17093152543069789893,
                                        "INDPRO.csv" => 10062885073871801530,
                                        "TOTLQ.csv" => 13351129232652546681,
                                        "EMRATIO.csv" => 16365288808354535060,
                                        "LNS12300006.csv" => 6932484352045138290,
                                        "LNS12300009.csv" => 7707514530963284877,
                                        "LNS12300031.csv" => 17090641733883191135,
                                        "LNS12300032.csv" => 352855425927135986)

    # Load monthly data
    data = RED.load_data_from_list(list_filenames_hashes = data_hashes,
                                   verbose = verbose)

    quarterly_data = data[:quarterly]
    monthly_data = data[:monthly]

    # Load NBER peaks and troughs
    nber_data_hashes = Dict{String, Integer}("NBER_peaks.txt" => 4901701600789099464,
		                             "NBER_troughs.txt" => 14025698590750588114);

    # This block converts NBER dates in text-form into Julia dates for NBER peaks and troughs.
    nber_cycles = RED.load_nber_cycles(nber_data_hashes = nber_data_hashes, data_folder = data_folder)

    # Check if both indicators exist monthly
    if in(gdp_symbol, names(monthly_data)) & in(emp_symbol, names(monthly_data))
        df = monthly_data
        peaks = nber_cycles[:NBER_peaks_month]
        troughs = nber_cycles[:NBER_troughs_month]
        println("Monthly!")
    else
        df = quarterly_data
        peaks = nber_cycles[:NBER_peaks_quarter]
        troughs = nber_cycles[:NBER_troughs_quarter]
    end
    
    recovery_target_log = log(1 + recovery_percent / 100);

    # GDP should always be in levels, suitable for logarithm    
    gdp_log_symbol = Symbol(string(gdp_symbol) * "_log")
    df[gdp_log_symbol] = log.(df[gdp_symbol])

    # Employment may be a rate, such as employment rate, in which case do not take logs
    emp_lowercase = lowercase(string(emp_symbol))
    employment_is_rate = endswith(emp_lowercase, "ratio") | startswith(emp_lowercase, "lns1230")
    if (employment_is_rate)
        emp_symbol_local = emp_symbol

        # Unit for the plot: percentage points
        unit = "pp"
    else
        emp_symbol_local = Symbol(string(emp_symbol) * "_log")
        df[emp_log_symbol] = log.(df[emp_symbol])

        # Unit for the plot: percentages
        unit = "%"
    end

    # Compute recoveries
    recoveries = RED.compute_recovery_of_employment_at_given_recovery_of_output(df = df,
									        gdp_log_column = gdp_log_symbol,
                                                                                emp_column = emp_symbol_local,
                                                                                employment_is_rate = employment_is_rate,
									        recovery_target_log = recovery_target_log,
									        peaks = peaks,
									        troughs = troughs)

    # Indices before and after 1990
    before_1990 = find(recoveries[:year] .< 1990)
    after_1990 = find(recoveries[:year] .>= 1990)

    # Linear regression to get the mean and its standard error
    before_fit = fit(LinearModel, @formula(recovery ~ 1), recoveries[before_1990, :])
    after_fit = fit(LinearModel, @formula(recovery ~ 1), recoveries[after_1990, :])

    before_avg = coef(before_fit)[1]
    before_sd = stderror(before_fit)[1]

    after_avg = coef(after_fit)[1]
    after_sd = stderror(after_fit)[1]

    interval_95 = 1.96

    before_plus = before_avg + interval_95 * before_sd
    before_minus = before_avg - interval_95 * before_sd

    after_plus = after_avg + interval_95 * after_sd
    after_minus = after_avg - interval_95 * after_sd

    # Verify that I got the intervals right
    @assert isapprox(2 * interval_95 * before_sd, before_plus - before_minus)
    @assert isapprox(2 * interval_95 * after_sd, after_plus - after_minus)

    filepath_with_extension = filepath * ".png"
    if true
        # Version with Gadfly
        
        p = plot(x = recoveries[:year],
                 y = recoveries[:recovery],
                 Geom.bar,
                 Scale.x_discrete,
                 Scale.y_continuous(minvalue = min(before_minus, after_minus), maxvalue = max(before_plus, after_plus)),
                 yintercept=[0,
                             before_avg, before_plus, before_minus,
                             after_avg, after_plus, after_minus],
                 Geom.hline(color = ["black", "green", "green", "green", "blue", "blue", "blue"],
                            style = [:solid, :solid, :dash, :dash, :solid, :dash, :dash]),
                 Guide.ylabel("Employment recovery for " * string(recovery_percent) * "% recovery of output (" * unit * ")", orientation = :vertical),
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
                  before_avg, before_plus, before_minus,
                  after_avg, after_plus, after_minus],
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

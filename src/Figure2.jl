function Figure2(; filepath::String = nothing)

    name = "B935RG3Q086SBEA"
    name_symbol = Symbol(name)
    
    # Verify hashes of files, otherwise things may change inadvertently
    price = RED.filename_and_hash_to_df(filename = name * ".csv", expected_hash = 7987295896397858414)

    # Normalize the last price to 1 + an epsilon, to fit in the viewport of Gadfly
    eps = 1e-1
    price[name_symbol] = price[name_symbol] / price[name_symbol][end] * (1 + eps)

    # Limit to after 1960
    years = map(Dates.year, price[:DATE])
    after_1960 = years .>= 1960
    
    price = price[after_1960, :]

    # Compute slope
    slope_log = log(price[name_symbol][end]/price[name_symbol][1]) / (Dates.year(price[:DATE][end]) - Dates.year(price[:DATE][1]))
    slope_percent = Integer(round(100 * (exp(slope_log) - 1), 0))
    
    # Plot on log-10 scale
    global theme
    p = plot(x = price[:DATE],
             y = price[:B935RG3Q086SBEA],
             Scale.y_log10(minvalue = 1, maxvalue = 1e4),
             Scale.x_continuous(minvalue = Dates.Date(1960, 1, 1), maxvalue = Dates.Date(2020, 1, 1)),
             theme,
             Geom.line,
             Guide.xlabel("Years"),
             Guide.ylabel("Computer price index (2018 = 1)"),
             #Guide.title("Exponential decline in computer prices at " * string(slope_percent) * "% per year")
             #Guide.annotation(compose(context(), Compose.text(0.6w, 0.2h, "Slope: " * string(slope_percent) * "% per year")))
             Guide.annotation(compose(context(), Compose.text(Dates.Date(2010, 1, 1), log10(1e2), "Slope: " * string(slope_percent) * "% per year")))
             )
    RED.export_plot(plot = p, filepath_without_extension = filepath)
end

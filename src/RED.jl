#__precompile__(true)

module RED

using DataFrames
using CSV
using GLM, StatsModels
using Cairo
#using Plots
using Gadfly
using Compose

# Global variables
global data_folder = "data";

global theme = Theme(bar_highlight = colorant"dark grey",
                   bar_spacing = 2mm,
                   major_label_font = "Arial Rounded MT Bold",
                   major_label_font_size = 12pt,
                   minor_label_font = "Arial Rounded MT Bold",
                   minor_label_font_size = 10pt,
                   line_width = 2px)

include("data_functions.jl")
include("Figure1.jl")
include("Figure2.jl")

end

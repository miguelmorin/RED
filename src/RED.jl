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


include("data_functions.jl")
include("Figure1.jl")
include("Figure2.jl")

end

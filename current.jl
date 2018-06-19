
# Add packages: do this once
if false
    Pkg.update()
    Pkg.add.(["Revise", "Gallium", "DataFrames", "CSV", "GLM", "StatsModels", "Gadfly", "Cairo", "Documenter"])
end

# Package for debugging
#using Gallium

# Include my package
include("src/RED.jl")

# Use this package to revise source code in the same REPL session, as in this answer:
# https://stackoverflow.com/questions/25028873/how-do-i-reload-a-module-in-an-active-julia-session-after-an-edit/50816280#50816280
using Revise

# Import the package functions into Main, accessible with RED.[name]
import RED

RED.Figure1(filepath = "results/figure1 monthly", gdp_symbol = :INDPRO, emp_symbol = :USGOOD)

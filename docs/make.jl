using Documenter, RED

makedocs(
    modules = [RED],
    format = :html,
    sitename = "RED.jl",
    authors = "Miguel Morin",
    doctest = true
)

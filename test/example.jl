using Test
using TestReports

(@testset ReportingTestSet "Example" begin
    recordproperty("TestReportsWrapper", true)
    include("example_normaltestsets.jl")
end) |> report |> println

using Test
using SDMX

@testset "SDMX.jl" begin
    @testset "URL Building" begin
        # Test SDMX 2.1
        q21 = SDMXQuery(
            endpoint="https://data-api.ecb.europa.eu/service",
            agency_id="ECB",
            api_version="2.1",
            flow_ref="EXR",
            key="A.USD.EUR.SP00.A",
            parameters=Dict("startPeriod" => "2020", "format" => "jsondata")
        )
        url, headers = SDMX.build_url(q21)
        @test occursin("https://data-api.ecb.europa.eu/service/data/EXR/A.USD.EUR.SP00.A", url)
        @test occursin("startPeriod=2020", url)
        @test occursin("format=jsondata", url)
        @test headers["Accept"] == "application/vnd.sdmx.data+json;version=1.0.0-wd"

        # Test SDMX 3.0
        q30 = SDMXQuery(
            endpoint="https://fusion.metadatatechnology.com/ws/public/sdmxapi/rest",
            agency_id="WB",
            api_version="3.0",
            context="dataflow",
            flow_ref="WDI",
            flow_version="1.0",
            key="A.SP_POP_TOTL.AFG",
            parameters=Dict("startPeriod" => "2020")
        )
        url, headers = SDMX.build_url(q30)
        @test occursin("dataflow/WB,WDI,1.0/A.SP_POP_TOTL.AFG", url)
        @test headers["Accept"] == "application/vnd.sdmx.data+json;version=2.0.0"
    end

    @testset "Data Fetch and Transform (ECB 2.1)" begin
        q = SDMXQuery(
            endpoint="https://data-api.ecb.europa.eu/service",
            agency_id="ECB",
            api_version="2.1",
            flow_ref="EXR",
            key="A.USD.EUR.SP00.A",
            parameters=Dict("startPeriod" => "2020", "format" => "jsondata", "detail" => "dataonly", "dimensionAtObservation" => "AllDimensions")
        )
        raw_data = SDMX.get(q)
        @test raw_data.status == 200
        @test !isempty(raw_data.payload)

        # Transform data
        tbl = transform(raw_data)
        @test tbl isa NamedTuple
        @test haskey(tbl, :OBS_VALUE)
        @test length(tbl.OBS_VALUE) > 0
    end

    @testset "listdimensions" begin
        q = SDMXQuery(
            endpoint="https://data-api.ecb.europa.eu/service",
            agency_id="ECB",
            api_version="2.1",
            flow_ref="EXR",
        )
        dims = listdimensions(q)
        @test dims isa NamedTuple
        @test haskey(dims, :DIM_ID)
        @test "FREQ" in dims.DIM_ID
        @test "Quarterly" in dims.VALUE_NAME
    end
end
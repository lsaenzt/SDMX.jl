#--------------------------------------------------------------------
# Helper functions for certain agencies
#--------------------------------------------------------------------

# Defines a query for the ECB  -> This should work with SDMX 2.1
ECBquery(flow_ref::String, key::Union{String,Vector{String}}="all") = SDMXQuery(
    endpoint="https://data-api.ecb.europa.eu/service",
    agency_id="ECB",
    api_version="2.1",
    context="dataflow",
    resource="data",
    flow_ref=flow_ref,
    flow_version="1.0",
    key=key,
    parameters=Dict(
        "dimensionAtObservation" => "AllDimensions"
    )
)

# Defines a query for the OECD -> This should work with SDMX 3.0
const OECDendpoint = "https://sdmx.oecd.org/public/rest/v2"

OECDquery(flow_ref::String, key::Union{String,Vector{String}}="all") = SDMXQuery(
    endpoint=OECDendpoint,
    agency_id="OECD",
    api_version="3.0",
    context="dataflow",
    resource="data",
    flow_ref=flow_ref,
    flow_version="1.0",
    key=key,
    parameters=Dict(
        "dimensionAtObservation" => "AllDimensions"
    )
)

# Defines a query for Eurostat. This should work with SDMX 2.1 but JSON is not available for structure queries
Eurostatquery(flow_ref::String, key::Union{String,Vector{String}}="all") = SDMXQuery(
    endpoint="https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1",
    agency_id="ESTAT",
    api_version="2.1",
    context="dataflow",
    resource="data",
    flow_ref=flow_ref,
    flow_version="1.0",
    key=key,
    parameters=Dict(
        "dimensionAtObservation" => "AllDimensions"
    )
)

#Defines a query for the World Bank
WorldBankquery(flow_ref::String, key::Union{String,Vector{String}}="all") = SDMXQuery(
    endpoint="https://api.worldbank.org/v2/country/all/indicator/",
    agency_id="WDI",
    api_version="2.1",
    context="dataflow",
    resource="data",
    flow_ref=flow_ref,
    flow_version="1.0",
    key=key,
    parameters=Dict(
        "dimensionAtObservation" => "AllDimensions"
    )
)

#Defines a query for the IMF
IMFquery(flow_ref::String, key::Union{String,Vector{String}}="all") = SDMXQuery(
    endpoint="https://data.imf.org/rest/sdmx/2.1/data",
    agency_id="IMF",
    api_version="2.1",
    context="dataflow",
    resource="data",
    flow_ref=flow_ref,
    flow_version="1.0",
    key=key,
    parameters=Dict(
        "dimensionAtObservation" => "AllDimensions"
    )
)

#Defines a query for the BIS
BISquery(flow_ref::String, key::Union{String,Vector{String}}="all") = SDMXQuery(
    endpoint="https://stats.bis.org/api/v2/data",
    agency_id="BIS",
    api_version="2.1",
    context="dataflow",
    resource="data",
    flow_ref=flow_ref,
    flow_version="1.0",
    key=key,
    parameters=Dict(
        "dimensionAtObservation" => "AllDimensions"
    )
)
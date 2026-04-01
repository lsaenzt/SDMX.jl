module SDMX

using HTTP
using JSON

export SDMXQuery, getdata, transform, getdimensions, getdataflows

# ==========================================
# Definición de Estructuras de Datos
# ==========================================

"""
Estructura que encapsula los parámetros de una consulta SDMX.
Es agnóstica a la agencia, requiriendo definir 'endpoint' y 'agency_id'.
"""
Base.@kwdef struct SDMXQuery
    endpoint::String
    agency_id::String # Obligatorio: Identificador del organismo (ej. "ESTAT", "ECB", "OECD")
    api_version::String = "3.0"
    resource::String = "data"
    context::String = "dataflow"
    flow_ref::String
    flow_version::String = "1.0"
    key::Union{String,Vector{String}} = "all"
    parameters::Dict{String,String} = Dict(
        "dimensionAtObservation" => "AllDimensions"
    )
end

struct SDMXRawData
    query::SDMXQuery
    status::Int
    payload::Vector{UInt8}
end

# ==========================================
# Funciones de Extracción (Extract)
# ==========================================

function build_url(q::SDMXQuery)
    actual_key = q.key isa Vector ? join(q.key, ".") : q.key

    local base::String
    local headers::Dict{String,String}
    if q.api_version == "2.1"
        headers = Dict("Accept" => "application/vnd.sdmx.data+json;version=1.0.0-wd")
        base = join([q.endpoint, q.resource, q.flow_ref, actual_key], "/")
    elseif q.api_version == "3.0"
        headers = Dict("Accept" => "application/vnd.sdmx.data+json;version=2.0.0")
        urn_group = join([q.agency_id, q.flow_ref, q.flow_version], ",")
        base = join([q.endpoint, q.resource, q.context, urn_group, actual_key], "/")
    else
        error("Versión de API no soportada. Usa '2.1' o '3.0'.")
    end

    query_string = HTTP.URIs.escapeuri(q.parameters)
    url = isempty(query_string) ? base : "$base?$query_string"

    return url, headers
end

function getdata(q::SDMXQuery)::SDMXRawData
    url, headers = build_url(q)
    @info "Ejecutando petición a: $url"

    response = HTTP.get(url, headers; readtimeout=60, retry=true, retries=3, status_exception=false)

    if response.status == 404
        @warn "Datos no encontrados (HTTP 404). Es posible que la combinación de filtros no exista."
        return SDMXRawData(q, response.status, UInt8[])
    elseif response.status != 200
        error("Fallo crítico al descargar datos SDMX. HTTP Status: $(response.status)")
    end

    return SDMXRawData(q, response.status, response.body)
end

# ==========================================
# Funciones de Transformación (Transform)
# ==========================================

function transform(raw_data::SDMXRawData)
    if raw_data.status == 404 || isempty(raw_data.payload)
        @warn "Transformación omitida debido a payload vacío. Se devuelve una tabla vacía."
        return NamedTuple()
    end

    json_obj = JSON.parse(raw_data.payload)

    if raw_data.query.api_version == "2.1"
        return _transform_v2(json_obj)
    elseif raw_data.query.api_version == "3.0"
        return _transform_v3(json_obj)
    end
end

function _transform_v2(json_obj)
    base_obj = haskey(json_obj, :data) ? json_obj.data : json_obj
    dims = base_obj.structure.dimensions.observation
    dim_names = Tuple(Symbol(d.id) for d in dims)
    dim_codes = [[String(v.id) for v in d.values] for d in dims]

    obs_dict = base_obj.dataSets[1].observations
    n_obs = length(obs_dict)

    columns = [Vector{String}(undef, n_obs) for _ in 1:length(dims)]
    obs_values = Vector{Union{Float64,Missing}}(undef, n_obs)

    idx = 1
    for (k, v) in obs_dict
        indices = split(string(k), ':')
        for (dim_idx, str_idx) in enumerate(indices)
            columns[dim_idx][idx] = dim_codes[dim_idx][parse(Int, str_idx)+1]
        end
        val = v[1]
        obs_values[idx] = val === nothing ? missing : Float64(val)
        idx += 1
    end

    return NamedTuple{(dim_names..., :OBS_VALUE)}((columns..., obs_values))
end

function _transform_v3(json_obj)
    base_obj = haskey(json_obj, :data) ? json_obj.data : json_obj

    dims_obj = base_obj.structure.dimensions
    dims = haskey(dims_obj, :observation) ? dims_obj.observation : dims_obj.dataset

    dim_names = Tuple(Symbol(d.id) for d in dims)
    dim_codes = [[String(v.id) for v in d.values] for d in dims]

    obs_dict = base_obj.dataSets[1].observations
    n_obs = length(obs_dict)

    columns = [Vector{String}(undef, n_obs) for _ in 1:length(dims)]
    obs_values = Vector{Union{Float64,Missing}}(undef, n_obs)

    idx = 1
    for (k, v) in obs_dict
        indices = split(string(k), ':')
        for (dim_idx, str_idx) in enumerate(indices)
            columns[dim_idx][idx] = dim_codes[dim_idx][parse(Int, str_idx)+1]
        end
        val = v[1]
        obs_values[idx] = val === nothing ? missing : Float64(val)
        idx += 1
    end

    return NamedTuple{(dim_names..., :OBS_VALUE)}((columns..., obs_values))
end

"""
    getdimensions(q::SDMXQuery)

Obtiene las dimensiones y valores disponibles de una consulta SDMX para explorar
sus posibles filtros, de modo que el usuario pueda diseñar el campo `key`.
"""
function getdimensions(q::SDMXQuery)
    local base::String
    local headers::Dict{String,String}

    if q.api_version == "2.1"
        headers = Dict("Accept" => "application/vnd.sdmx.data+json;version=1.0.0-wd")
        base = join([q.endpoint, q.resource, q.flow_ref, "all"], "/")
    elseif q.api_version == "3.0"
        headers = Dict("Accept" => "application/vnd.sdmx.data+json;version=2.0.0")
        urn_group = join([q.agency_id, q.flow_ref, q.flow_version], ",")
        base = join([q.endpoint, q.resource, q.context, urn_group, "all"], "/")
    else
        error("Versión de API no soportada. Usa '2.1' o '3.0'.")
    end

    # Parámetros óptimos para extraer solo la estructura de dimensiones
    params = Dict("detail" => "serieskeysonly", "lastNObservations" => "1")
    query_string = HTTP.URIs.escapeuri(params)
    url = "$base?$query_string"

    @info "Obteniendo dimensiones desde: $url"
    resp = HTTP.get(url, headers; readtimeout=60, retry=true, retries=3)

    json_obj = JSON.parse(resp.body)
    base_obj = haskey(json_obj, :data) ? json_obj.data : json_obj
    dims_obj = base_obj.structure.dimensions

    # Identifica si la respuesta usa :series, :observation o :dataset
    ds = haskey(dims_obj, :series) ? dims_obj.series :
         (haskey(dims_obj, :observation) ? dims_obj.observation : dims_obj.dataset)

    dim_ids = String[]
    dim_names = String[]
    value_ids = String[]
    value_names = String[]

    for dsᵢ in ds
        for j in dsᵢ.values
            push!(dim_ids, String(dsᵢ.id))
            push!(dim_names, String(dsᵢ.name))
            push!(value_ids, String(j.id))
            push!(value_names, String(j.name))
        end
    end

    return (DIM_ID=dim_ids,
        DIM_NAME=dim_names,
        VALUE_ID=value_ids,
        VALUE_NAME=value_names)
end


"""
    getdataflows(endpoint::String, sdmxversion::String="3.0")

Obtiene los dataflows disponibles de una consulta SDMX.
"""
function getdataflows(endpoint::String, sdmxversion::String="3.0")

    if sdmxversion == "2.1"
        println("not yet...")
    elseif sdmxversion == "3.0"
        url = join([endpoint, "structure/dataflow/*?detail=allstubs"], "/")
        response = HTTP.get(url, Dict("Accept" => "application/vnd.sdmx.structure+json;version=1.0"))
    else
        error("SDMX version not supported. Use '2.1' or '3.0'.")
    end

    json_obj = JSON.parse(response.body)
    base_obj = haskey(json_obj, :data) ? json_obj.data : json_obj
    dflows = base_obj.dataflows

    # Identifica si la respuesta usa :series, :observation o :dataset

    ids = String[]
    names = String[]

    for dsᵢ in dflows
        push!(ids, String(dsᵢ.id))
        push!(names, String(dsᵢ.name))
    end

    return (ID=ids, NAME=names)

end # function

end # module
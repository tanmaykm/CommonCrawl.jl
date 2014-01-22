
type HTTPHeaderStats
    http_version::String
    charset::String
    server_make::String
    server_version::String
    
    tld::String
    public_suffix::String
end

type CorpusStats
    ndocs::Int

    http_versions::Dict{String,Int}
    charsets::Dict{String,Int}
    mime_types::Dict{String,Int}
    server_makes::Dict{String,Int}
    server_make_versions::Dict{String,Int}

    tlds::Dict{String,Int}
    public_suffixes::Dict{String,Int}

    average_doc_size::Int

    website_data_size::Dict{String,Int}
    website_doc_count::Dict{String,Int}

    function CorpusStats()
        new(0, 
            Dict{String,Int}(),
            Dict{String,Int}(),
            Dict{String,Int}(),
            Dict{String,Int}(),
            Dict{String,Int}(),
            Dict{String,Int}(),
            Dict{String,Int}(),
            0,
            Dict{String,Int}(),
            Dict{String,Int}())
    end
end

function analyze_header(entry::ArchiveEntry)
    http_version = (!isempty(entry.http_status) && ('/' in entry.http_status)) ? split(split(entry.http_status, '/', 2)[2], ' ', 2)[1] : ""

    hdrs = entry.http_hdrs
    charset = haskey(hdrs, "x-commoncrawl-detectedcharset") ? hdrs["x-commoncrawl-detectedcharset"] : ""
    if haskey(hdrs, "server")
        parts = split(hdrs["server"], '/', 2)
        server_make = parts[1]
        server_version = ((length(parts) > 1) && !isempty(strip(parts[2]))) ? split(parts[2])[1] : ""
    else
        server_make = server_version = ""
    end

    top_domain = public_suffix = ""
    try
        d = Domain(URI(escape_with(entry.uri, "!")).host)
        top_domain = d.top_domain
        public_suffix = d.public_suffix
    end

    HTTPHeaderStats(http_version, charset, server_make, server_version, top_domain, public_suffix)
end

incr(d::Dict{String,Int}, key::String, v::Int=1) = (d[key] = (get(d, key, 0) + v))
function incr(d::Dict{String,Int}, d2::Dict{String,Int})
    for (n,v) in d2
        incr(d, n, v)
    end
    d
end

function analyze_corpus(arcs::Array{ArchiveEntry,1}, stats::CorpusStats=CorpusStats())
    total_doc_sz = stats.average_doc_size * stats.ndocs
    ndocs = stats.ndocs

    http_versions = stats.http_versions
    charsets = stats.charsets
    mime_types = stats.mime_types
    server_makes = stats.server_makes
    server_make_versions = stats.server_make_versions

    tlds = stats.tlds
    public_suffixes = stats.public_suffixes

    website_data_size = stats.website_data_size
    website_doc_count = stats.website_doc_count

    for entry in arcs
        hdr_stats = analyze_header(entry)
        total_doc_sz += entry.len
        ndocs += 1

        incr(http_versions, hdr_stats.http_version)
        incr(charsets, hdr_stats.charset)
        incr(mime_types, entry.mime)
        incr(server_makes, hdr_stats.server_make)
        incr(server_make_versions, join([hdr_stats.server_make, hdr_stats.server_version], ' '))
        incr(tlds, hdr_stats.tld)
        incr(public_suffixes, hdr_stats.public_suffix)
        incr(website_data_size, hdr_stats.public_suffix, entry.len)
        incr(website_doc_count, hdr_stats.public_suffix)
    end
    stats.average_doc_size = int(total_doc_sz / ndocs)
    stats.ndocs = ndocs
    stats
end


function merge_corpus_stats(stats_list::Array{CorpusStats,1}, stats::CorpusStats=CorpusStats())
    total_doc_sz = 0
    ndocs = 0

    dict_names = [:http_versions, :charsets, :mime_types, :server_makes, :server_make_versions, :tlds, :public_suffixes, :website_data_size, :website_doc_count]
    dicts = [getfield(stats, x) for x in dict_names]

    for stat in stats_list
        total_doc_sz += (stat.average_doc_size * stat.ndocs)
        ndocs += stat.ndocs

        for idx in 1:length(dict_names)
            incr(dicts[idx], getfield(stat, dict_names[idx]))
        end
    end
    stats.average_doc_size = int(total_doc_sz / ndocs)
    stats.ndocs = ndocs
    stats
end

function print_corpus_stats(stats::CorpusStats)
    println("document count: $(stats.ndocs)")
    println("mean doc size: $(stats.average_doc_size) bytes")

    dict_names = [:http_versions, :charsets, :mime_types, :server_makes, :server_make_versions, :tlds, :public_suffixes, :website_data_size, :website_doc_count]
    dicts = [getfield(stats, x) for x in dict_names]

    for idx in 1:length(dict_names)
        println("")
        println("-"^20)
        println("$(dict_names[idx])")
        println("-"^20)
        pq = Base.Collections.PriorityQueue(dicts[idx], Base.Order.Reverse)
        for didx in 1:min(20,length(pq))
            n = Base.Collections.dequeue!(pq)
            v = (dicts[idx])[n]
            #println("$n : $v")
            @printf "%50s : %20.0d\n" n v
        end
    end
end


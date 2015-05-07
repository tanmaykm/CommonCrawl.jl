
type HTTPHeaderStats
    http_version::AbstractString
    charset::AbstractString
    server_make::AbstractString
    server_version::AbstractString
    
    tld::AbstractString
    public_suffix::AbstractString
end

type CorpusStats
    ndocs::Int

    http_versions::Dict{AbstractString,Int}
    charsets::Dict{AbstractString,Int}
    mime_types::Dict{AbstractString,Int}
    server_makes::Dict{AbstractString,Int}
    server_versions::Dict{AbstractString,Int}

    tlds::Dict{AbstractString,Int}
    public_suffixes::Dict{AbstractString,Int}

    average_doc_size::Int

    website_data_size::Dict{AbstractString,Int}
    website_doc_count::Dict{AbstractString,Int}

    function CorpusStats()
        new(0, 
            Dict{AbstractString,Int}(),
            Dict{AbstractString,Int}(),
            Dict{AbstractString,Int}(),
            Dict{AbstractString,Int}(),
            Dict{AbstractString,Int}(),
            Dict{AbstractString,Int}(),
            Dict{AbstractString,Int}(),
            0,
            Dict{AbstractString,Int}(),
            Dict{AbstractString,Int}())
    end
end

function analyze_header(entry::ArchiveEntry)
    http_version = (!isempty(entry.http_status) && ('/' in entry.http_status)) ? split(split(entry.http_status, '/', 2)[2], ' ', 2)[1] : ""

    hdrs = entry.http_hdrs
    charset = haskey(hdrs, "x-commoncrawl-detectedcharset") ? hdrs["x-commoncrawl-detectedcharset"] : ""
    if haskey(hdrs, "server")
        parts = split(hdrs["server"], '/', 2)
        lsm = lowercase(parts[1])
        server_make = contains(lsm, "apache") ? "Apache" :
            contains(lsm, "nginx") ? "Nginx" :
            parts[1]
        server_version = strip(parts[1] * " " * (((length(parts) > 1) && !isempty(strip(parts[2]))) ? split(parts[2])[1] : ""))
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

incr(d::Dict{AbstractString,Int}, key::AbstractString, v::Int=1) = (d[key] = (get(d, key, 0) + v))
function incr(d::Dict{AbstractString,Int}, d2::Dict{AbstractString,Int})
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
    server_versions = stats.server_versions

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
        incr(server_versions, hdr_stats.server_version)
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

    dict_names = [:http_versions, :charsets, :mime_types, :server_makes, :server_versions, :tlds, :public_suffixes, :website_data_size, :website_doc_count]
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

    dict_names = [:http_versions, :charsets, :mime_types, :server_makes, :server_versions, :tlds, :public_suffixes, :website_data_size, :website_doc_count]
    dicts = [getfield(stats, x) for x in dict_names]

    for idx in 1:length(dict_names)
        println("")
        println("-"^70)
        @printf "%-25s%15s%13s%13s\n" "$(dict_names[idx])" "name" "abs" "pct"
        println("-"^70)
        tot = sum(collect(values(dicts[idx])))
        pq = Base.Collections.PriorityQueue(dicts[idx], Base.Order.Reverse)
        didx = 1
        others = 0
        while (didx <= 20) && !isempty(pq)
            n = Base.Collections.dequeue!(pq)
            v = (dicts[idx])[n]
            if isempty(n)
                others += v
            else
                @printf "%40s : %10.0d : %10.6f\n" n v (v*100/tot)
                didx += 1
            end
        end
        while !isempty(pq)
            n = Base.Collections.dequeue!(pq)
            others += (dicts[idx])[n]
        end
        if others > 0
            @printf "%40s : %10.0d : %10.6f\n" "others" others (others*100/tot)
        end
    end
end


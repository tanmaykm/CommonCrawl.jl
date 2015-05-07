
type CrawlCorpus
    cloc::AbstractString
    debug::Bool
    function CrawlCorpus(cache_location::AbstractString, debug::Bool=false)
        isempty(cache_location) && error("cache location must be set to a valid directory")
        new(cache_location, debug)
    end
end

#TODO:
# server type
# character encoding
# server OS
# top level domain
# public suffix of domain
# second level domain
type ArchiveEntry
    uri::AbstractString
    mime::AbstractString
    len::Int
    http_status::AbstractString
    http_hdrs::Dict{ASCIIString,AbstractString}
    data::Array
end

function clear_cache(cc::CrawlCorpus)
    cc.debug && println("clearing cached files...")
    for f in readdir(cc.cloc)
        cc.debug && println("\t$f")
        rm(joinpath(cc.cloc, f))
    end   
end

function clear_cache(cc::CrawlCorpus, archive::URI)
    fname = basename(archive.path)
    docsfile = joinpath(cc.cloc, fname)
    cc.debug && println("clearing cached file $fname")
    isfile(docsfile) && rm(docsfile)
    nothing
end

function segments(cc::CrawlCorpus)
    file = joinpath(cc.cloc, "valid_segments.txt")
    if !isfile(file)
        cc.debug && println("fetching valid segments...")
        t1 = time()
        os = open(file, "w")
        ho = HTTPClient.HTTPC.RequestOptions(ostream=os)
        get("http://aws-publicdatasets.s3.amazonaws.com/common-crawl/parse-output/valid_segments.txt", ho)
        close(os)
        cc.debug && println("\tfetched in $(time()-t1)secs")
    end
    segnames = AbstractString[]
    open(file) do f
        for str in readlines(f)
            push!(segnames, chomp(str))
        end
    end
    segnames
end

function archives(cc::CrawlCorpus, segment::AbstractString)
    file = joinpath(cc.cloc, string("segment_list_",segment,".txt"))
    arcnames = URI[]
    if !isfile(file)
        cc.debug && println("listing segment $segment")
        t1 = time()
        env = AWSEnv(timeout=60.0)
        segname = string("common-crawl/parse-output/segment/", segment)
        os = open(file, "w")
        opts = GetBucketOptions(prefix=segname)
        while true
            resp = S3.get_bkt(env, "aws-publicdatasets", options=opts)
            for elem in resp.obj.contents
                if endswith(elem.key, ".arc.gz")
                    uri_str = string("http://aws-publicdatasets.s3.amazonaws.com/", elem.key)
                    push!(arcnames, URI(uri_str))
                    println(os, uri_str)
                end
                opts.marker = elem.key
            end
            !resp.obj.isTruncated && break
        end
        close(os)
        cc.debug && println("\tfetched in $(time()-t1)secs")
    else
        cc.debug && println("opening cached file [$(file)]")
        open(file) do f
            for str in readlines(f)
                push!(arcnames, URI(chomp(str)))
            end
        end
    end
    cc.debug && println("$(length(arcnames)) archives in segment $(segment)")
    arcnames
end

function archives(cc::CrawlCorpus, count::Int=0)
    arcs = URI[]
    for seg in segments(cc)
        arcs_in_seg = archives(cc, seg)
        append!(arcs, arcs_in_seg)
        (count > 0) && (length(arcs) >= count) && break
    end
    (count == 0) ? arcs : arcs[1:count]
end

function open(cc::CrawlCorpus, archive::URI)
    fname = basename(archive.path)
    docsfile = joinpath(cc.cloc, fname)
    cc.debug && println("opening $archive. ($docsfile)")
    if !isfile(docsfile)
        cc.debug && println("\tdownloading $archive to $docsfile")
        t1 = time()
        os = open(docsfile, "w")
        ho = HTTPClient.HTTPC.RequestOptions(ostream=os)
        get(string(archive), ho)
        close(os)
        cc.debug && println("\tdownloaded in $(time()-t1)secs")
    end
    GZip.open(docsfile, "r", 8192*10)
end


function read_entry(cc::CrawlCorpus, f::IO, mime_part::AbstractString="", metadata_only::Bool=false)
    while true
        l = readline(f)
        while !eof(f) && isempty(l)
            l = readline(f)
        end
        eof(f) && isempty(l) && return ArchiveEntry("","",0,"",Dict{ASCIIString,AbstractString}(),[])
        vs = split(l)

        uri = vs[1]
        mime = vs[4]
        len = parse(Int, vs[5])

        if !isempty(mime_part) && !startswith(mime, mime_part)
            skip(f, len)
            continue
        end

        # read the http header
        hdrs = Dict{ASCIIString,AbstractString}()
        http_status = ""
        hdrlen = 0
        while !eof(f)
            l = readline(f)
            hdrlen += length(l)
            l = strip(l)
            isempty(l) && break
            nv = split(l, ':'; limit=2)
            if length(nv) == 2
                hdrs[lowercase(strip(nv[1]))] = strip(nv[2])
            elseif startswith(l, "HTTP")
                http_status = l
            end
        end

        len -= hdrlen
        # read or skip the http data
        data = []
        if metadata_only
            skip(f, len)
        else
            data = read(f, Array(Uint8, len))
        end
        return ArchiveEntry(uri, mime, len, http_status, hdrs, data)
    end
end


function read_entries(cc::CrawlCorpus, f::IO, mime_part::AbstractString="", num_entries::Int=0, metadata_only::Bool=false)
    arcs = ArchiveEntry[]
    while !eof(f) 
        (num_entries > 0) && (length(arcs) >= num_entries) && break
        arc = read_entry(cc, f, mime_part, metadata_only)
        (!metadata_only) && isempty(arc.data) && continue
        push!(arcs, arc)
    end
    arcs
end



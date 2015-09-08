using CommonCrawl
using URIParser

cache_dir = joinpath(tempdir(), "cc")
!isdir(cache_dir) && mkdir(cache_dir)
cc = CrawlCorpus(cache_dir, true)

try
    segs = segments(cc)
    @assert !isempty(segs)
    for seg in segs[1:5]
        println("\t$(seg)")
    end
    println("\t... total $(length(segs))")

    println("fetching 10 archives...")
    arcs = archives(cc, 10)
    @assert length(arcs) == 10
    for arc in arcs
        println("\t$(arc)")
    end

    println("reading archive $(arcs[1]) for 10 entries")
    f = open(cc, arcs[1])
    text_entries = read_entries(cc, f, "text/", 10)
    @assert length(text_entries) == 10
    for entry in text_entries
        println("\t$(entry.mime) : $(length(entry.data)) : $(entry.uri)")
    end
    close(f)
finally
    clear_cache(cc)
    rm(cache_dir)
end

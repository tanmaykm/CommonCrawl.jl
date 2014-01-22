module CommonCrawl

using AWS
using AWS.S3
using GZip
using HTTPClient
using URIParser
using PublicSuffix

import Base.open

export CrawlCorpus, clear_cache, segments, archives, open, read_entry, read_entries
export HTTPHeaderStats, analyze_header, CorpusStats, analyze_corpus, merge_corpus_stats, print_corpus_stats

include("parse.jl")
include("analyze.jl")

end


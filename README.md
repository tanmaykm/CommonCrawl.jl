CommonCrawl.jl
==============

[![Build Status](https://travis-ci.org/tanmaykm/CommonCrawl.jl.png)](https://travis-ci.org/tanmaykm/CommonCrawl.jl)

Interface to the [common crawl dataset on Amazon S3](http://aws.amazon.com/datasets/41740)

## Usage

An instance of the corpus is obtained as:
````
cc = CrawlCorpus(cache_location::String, debug::Bool=false)
````
Since the crawl corpus files are large, they are cached locally by default at `cache_location`. The first time a file is accessed, it is downloaded in full into the cache location. Subsequent calls to read are served locally.

All cached files, or a particular cached archive file can be deleted:
````
clear_cache(cc::CrawlCorpus)
clear_cache(cc::CrawlCorpus, archive::URI)
````

Segments and archive files in a segment can be listed as: 
````
segment_names = segments(cc::CrawlCorpus)
archive_uris = archives(cc::CrawlCorpus, segment::String)
````

Archive files across all segments can be accessed easily as: 
````
archive_uris = archives(cc::CrawlCorpus, count::Int=0)
````
Passing count as `0` lists all available archive files (which can be large).

A particular archive file can be opened as:
````
open(cc::CrawlCorpus, archive::URI)
````

And crawl entries can be read from an opened archive as:
````
entry = read_entry(cc::CrawlCorpus, f::IO, mime_part::String="", metadata_only::Bool=false)
entries = read_entries(cc::CrawlCorpus, f::IO, mime_part::String="", num_entries::Int=0, metadata_only::Bool=false)
````
Method `read_entry` returns an `ArchiveEntry` instance corresponding to the next entry in the file with mime type beginning with `mime_part`. Method `read_entries` returns an array of `ArchiveEntry` objects. If `num_entries` is `0`, all matching entries in the archive file are returned. If `metadata_only` is true, only the file metadata (url and mime type) is populated in the entries.


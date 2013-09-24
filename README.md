CommonCrawl.jl
==============

Interface to the [common crawl dataset on Amazon S3](http://aws.amazon.com/datasets/41740)

## Usage

Create an instance of the corpus as:
````
cc = CrawlCorpus(cache_location::String, debug::Bool=false)
````
Since the crawl corpus files are large, the files are cached locally by default at `cache_location`. Accessing a file downloads the complete file and subsequent calls to read are served locally.

All cached files, or a particular cached archive file can be deleted through methods:
````
clear_cache(cc::CrawlCorpus)
clear_cache(cc::CrawlCorpus, archive::URI)
````

To list segments or archive files in a particular segment as array of URI objects:
````
segments(cc::CrawlCorpus)
archives(cc::CrawlCorpus, segment::String)
````

The following method lists archive files as an array of URI objects across segments:
````
archives(cc::CrawlCorpus, count::Int=0)
````
Passing count as 0 lists all available archive files (which can be large).

A particular archive file can be opened as:
````
open(cc::CrawlCorpus, archive::URI)
````

And files can be read from an opened archive as:
````
read_entry(cc::CrawlCorpus, f::IO, mime_part::String="")
read_entries(cc::CrawlCorpus, f::IO, mime_part::String="", num_entries::Int=0)
````
Method `read_entry` returns an `ArchiveEntry` instance corresponding to the next entry in the file with mime type beginning with `mime_part`. Method `read_entries` returns an array of `ArchiveEntry` objects. If `num_entries` is 0, all matching entries in the archive file are returned.


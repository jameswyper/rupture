require 'fileutils'
require_relative 'tag'
require 'shellwords'
require 'open3'
require 'pathname'

# minimal sanity-check on parameters

if ARGV.size < 2
    raise "Must specify source and target directories"
end

source = ARGV[0]
dest = ARGV[1] 
threads = ARGV[2] unless ARGV.size < 3
lameopts = ARGV[3] unless ARGV.size < 4

begin
    if threads then threads = threads.to_i else threads = 4 end
rescue
    raise "Threads parameter should be a number; was :#{threads}"
end

lameopts = "--preset standard" unless lameopts

# find out what files already exist

sourcelist = Dir[source + "/**/*.flac"]

$stderr.puts "#{sourcelist.size} files in source tree"
destlist = Dir[dest + "/**/*.mp3"]

desthash = Hash[destlist.collect{|f| [f,true]}]

sourcework = Array.new

# create a list of files that need to be converted because there isn't an up to date mp3

sourcelist.each do |sourcefile|
    mp3name = (sourcefile[0..-5] + "mp3").sub(source,dest)
    if desthash[mp3name]
        if File.mtime(sourcefile) > File.mtime(mp3name)
            sourcework << sourcefile
        end
        desthash[mp3name] = false
    else
        sourcework << sourcefile
    end
end

# create a list of files that should be deleted because there isn't a matching flac
# NTS - may want to rm directory / cover as well

destwork = Array.new
desthash.each {|k,v| if v then destwork << k end}

total = sourcework.size
$stderr.puts "#{total} files actually need converting"
current = 0

log = ""

mut = Mutex.new
worktodo = true

Thread.abort_on_exception = true
workers = Array.new

threads.times do
    workers << Thread.new do
        sourcefile = nil
        while worktodo do
            mut.synchronize do
                if sourcework.size > 0
                    sourcefile = sourcework.pop
                    current += 1
                else
                    worktodo = false
                end
            end
            if worktodo
                $stderr.puts "Working on file #{current}/#{total} #{sourcefile}"
                destfile = (sourcefile[0..-5] + "mp3").sub(source,dest)
                destdir = destfile[0...(destfile.rindex('/') )]
                mut.synchronize {FileUtils.makedirs(destdir)}
                cmd = "flac --decode -c -s --apply-replaygain-which-is-not-lossless #{Shellwords.escape(sourcefile)} | lame --silent #{lameopts} - #{Shellwords.escape(destfile)}"
                stdout,stderr,status = Open3.capture3(cmd)
                mut.synchronize do
                    flactag = GenericTag::Metadata.from_flac(sourcefile,false)
                    mp3tag = GenericTag::Metadata.convert(:id3v24,flactag)
                    mp3tag.to_mp3(destfile,true)
                end
                log << stderr
            end
        end    
    end
end

workers.each(&:join)

# create a file of stuff to rm

destdir = Hash.new
destwork.each do |f|
    pn = Pathname.new(f)
    destdir[pn.dirname] = true
    puts "rm -f #{Shellwords.escape(f)}"
end
destdir.keys.sort.reverse.each do |d|
    puts "rmdir #{Shellwords.escape(d)}"
end

#puts log

require 'optparse'
require 'pathname'
require 'logger'

require_relative 'musicfiles'

STDOUT.sync = true
$log = Logger.new(STDOUT) unless $log
$log.level = Logger::INFO

class Config

    def initialize(args = ARGV)
        OptionParser.new { |opts|
            opts.banner = "Usage: #{File.basename($0)} [options]"
            opts.on('-g', '--group GROUP', 'Scanning group') do |arg|
                @group = arg
            end
            opts.on('-r','--root DIRECTORY' ,'Directory to scan for music') do |arg|
                @root = File.expand_path(arg)
            end
            opts.on('-a','--acoustid TOKEN','AcoustID API token') do |arg|
                @token = arg
            end
            opts.on('-c','--candidates FILE','path to input file of candidate matches)') do |arg|
                @candfile = File.expand_path(arg)
            end
            opts.on('-m','--matches FILE','path to output file of multiple matches)') do |arg|
                @matchfile = File.expand_path(arg)
            end
        }.parse!(args)
    end

    def validate
        @group = "default" unless @group
        raise ArgumentError, "Scanning root (-r, --root) must be specified" unless @root
        raise ArgumentError, "Scanning root #{@root} is not a valid directory" unless File.directory?(@root)
        if @candfile
            raise ArgumentError, "Candidate file #{@candfile} not found" unless File.exists?(@candfile)
        end
        raise ArgumentError, "Matches file (-m, --matches) must be specified" unless @matchfile
        raise ArgumentError, "Directory for matches file #{@matchfile} not found" unless File.directory?(Pathname.new(@matchfile).dirname)
    end

    def dump
        $log.info("Group: #{@group}")
        $log.info("Scanning from: #{@root}")
        $log.info("AcoustID api token: #{@token}")
        $log.info("Candidates file: #{@candfile}")
        $log.info("Matches output to: #{@matchfile}")
    end

    attr_reader :group, :root, :token, :candfile, :matchfile
end

config = Config.new
config.validate
config.dump

t = MusicFiles::Tree.new(config.root,config.group)

puts "break"
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

##TODO - read in matchreport if present and bypass entries

t.findByOffsets
t.findByAcoustID

#TODO - make this next section group-specific

=begin
$log.info "Removing old data"
Model::Disc.delete_all
Model::MediumOffsetCandidate.delete_all
Model::File.delete_all
Model::MediumAcoustCandidate.delete_all
Model::Tag.delete_all


$log.info "Saving unfound"

ActiveRecord::Base.transaction do
	t.notFoundDiscs.each do |d| 
		md = Model::Disc.create(pathname: d.pathname, number: d.number)
		d.tracks.each_value do |f|
			mf = md.file.create(pathname: f.pathname, basename: f.basename, track: f.track)
			f.tags.each do |name, value|
				mf.tag.create(name: name, value: value)
			end
		end
	end
end

$log.info "Saving foundViaOffsets"

ActiveRecord::Base.transaction do
	t.foundDiscsViaOffsets.each do |d|
		md = Model::Disc.create(pathname: d.pathname, number: d.number)
		d.tracks.each_value do |f|
			mf = md.file.create(pathname: f.pathname, basename: f.basename, track: f.track)
			f.tags.each do |name, value|
				mf.tag.create(name: name, value: value)
			end
		end
		d.mediumCandidatesOffsets.each do |mc|
			md.mediumOffsetCandidate.create(medium_id: mc.id)
		end
	end
end

$log.info "Saving foundViaAcoustID"

ActiveRecord::Base.transaction do
	t.foundDiscsViaAcoustID.each do |d|
		md = Model::Disc.create(pathname: d.pathname, number: d.number)
		d.tracks.each_value do |f|
			mf = md.file.create(pathname: f.pathname, basename: f.basename, track: f.track)
			f.tags.each do |name, value|
				mf.tag.create(name: name, value: value)
			end
		end
		d.mediumCandidatesAcoustID.each do |mc|
			md.mediumAcoustCandidate.create(medium_id: mc.id)
		end
	end
end
=end
$log.info "done"

require 'optparse'
require 'yaml' 
module Meta
class Config
	
	attr_reader :directory, :errors, :forceScan, :discid, :acoustid, 
		:candidates,
		:mbServer, :mbdb, :acServer, :metadb, :offsets, :acToken, :fpcalc, :notFound, :acoustIDdb
	
	def initialize(args = ARGV)
		
		@file = File.expand_path("~/.config/metascan")
		@errors = Array.new
		
		OptionParser.new { |opts|
			opts.banner = "Usage: #{File.basename($0)} directory [options]"
			opts.on('-s', '--scan', 'Force rescan of directory') do |arg|
				@forceScan = true
			end
			opts.on('-c','--config FILE' ,'path to configuration file (defaults to $HOME/.config/metascan)') do |arg|
				@cmd_file = File.expand_path(arg)
			end
			opts.on('-a','--acoustid YESNO','enable/disable acoustid scanning (any value other than 0, n or no enables)') do |arg|
				@cmd_acoustid = arg.downcase
			end
			opts.on('-d','--discid YESNO','enable/disable discid scanning (any value other than 0, n or no enables)') do |arg|
				@cmd_discid = arg.downcase
			end			
			opts.on('-ca','--candidates FILE','path to input file of acoustid candidate matches)') do |arg|
				@cmd_cand = arg
			end
			opts.on('-t','--token TOKEN','token for AcoustID service') do |arg|
				@cmd_tok = arg
			end
			opts.on('-nf','--not-found FILE','path the output file of discs that couldn\'t be identified') do |arg|
				@cmd_nf	= arg
			end
		}.parse!(args)
		
		if args[0]
			@directory = args[0]
		else
			@errors <<   "directory argument not given" 
		end
		
		begin
			hin = YAML.load(File.read(@cmd_file ? @cmd_file : @file))
		rescue
			@errors <<   "error loading config file"
			hin = Hash.new
		end
		h = Hash.new
		hin.each{|k,v| h[k.downcase] = v}
		
		if h["musicbrainz_server"] then @mbServer = h["musicbrainz_server"] else @mbServer = "musicbrainz.org" end
		if h["musicbrainz_db"] then @mbdb = File.expand_path(h["musicbrainz_db"]) else @mbdb = File.expand_path("~/.cache/md.db") end
		if h["acoustid_server"] then @acServer = h["acoustid_server"] else @acServer = "https://api.acoustid.org" end
		if h["acoustid_token"] then @acToken = h["acoustid_token"] else @acToken = nil end
		if h["metadata_db"] then @metadb = File.expand_path(h["metadata_db"]) else @metadb = File.expand_path("~/.cache/meta.db") end
		if h["acoustid_db"] then @acoustIDdb = File.expand_path(h["acoustid_db"]) else @acoustIDdb = File.expand_path("~/.cache/acoustid.db") end			
		if h["discid_offsets"] then @offsets = h["discid_offsets"] .split(',').map {|o| o.to_i} else @offsets = [150,182,183,178,180,188,190] end
		if h["fpcalc"] then @fpcalc = h["fpcalc"] else @fpcalc = "fpcalc" end
		file_cand =  h["candidates"]
		file_nf = h["not_found"]

		case @cmd_dc
		when "0", "n", "no"
			@discid = false
		else 
			@discid = true
		end
		
		case @cmd_ac
		when "0", "n", "no"
			@acoustid = false
		else 
			@acoustid = true
		end

		@candidates = (@cmd_cand ? File.expand_path(@cmd_cand) : (file_cand ? File.expand_path(file_cand) : nil) )
		@notFound = (@cmd_nf ? File.expand_path(@cmd_nf) : (file_nf ? File.expand_path(file_nf) : nil) )
		
		if @cmd_tok
			@acToken = @cmd_tok
		else
			unless @acToken
				@errors <<  "No API token for AcoustID service specified either on command line or config file" 
			end
		end
	end
	
	
	
end
end
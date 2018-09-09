require 'optparse'
require 'yaml' 
module Meta
class Config
	
	attr_reader :directory, :errors, :forceScan, :discid, :acoustid, 
		:discidFileIn, :discidFileOut, :acoustidFileIn, :acoustidFileOut,
		:mbserver, :mbdb, :acserver, :acdb, :offsets, :actoken
	
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
			opts.on('-af','--acoustid-found FILE','path to file of acoustid matches (usually from a previous run)') do |arg|
				@cmd_af = arg
			end
			opts.on('-ac','--acoustid-candidates FILE','path to file of acoustid candidate matches)') do |arg|
				@cmd_ac = arg
			end
			opts.on('-df','--discid-found FILE','path to file of acoustid matches (usually from a previous run)') do |arg|
				@cmd_df = arg
			end
			opts.on('-dc','--discid-candidates FILE','path to file of discid candidate matches)') do |arg|
				@cmd_dc = arg
			end
			opts.on('-t','--token TOKEN','token for AcoustID service') do |arg|
				@cmd_tok = arg
			end
		}.parse!(args)
		
		if args[0]
			@directory = args[0]
		else
			@errors << ["directory argument not given"]
		end
		
		begin
			hin = YAML.load(File.read(@cmd_file ? @cmd_file : @file))
		rescue
			@errors <<  ["error loading config file"]
			hin = Hash.new
		end
		h = Hash.new
		hin.each{|k,v| h[k.downcase] = v}
		
		if h["musicbrainz_server"] then @mbserver = h["musicbrainz_server"] else @mbserver = "musicbrainz.org" end
		if h["musicbrainz_db"] then @mbdb = File.expand_path(h["musicbrainz_server"]) else @mbdb = File.expand_path("~/.cache/md.db") end
		if h["acoustid_server"] then @acserver = h["acoustid_server"] else @acserver = "acoustid.org" end
		if h["acoustid_token"] then @actoken = h["acoustid_token"] else @actoken = nil end
		if h["metadata_db"] then @metadb = File.expand_path(h["metadata_db"]) else @metadb = File.expand_path("~/.cache/meta.db") end
		if h["discid_offsets"] then @offsets = h["discid_offsets"] .map {|o| o.to_i} else @offsets = [150,182,183,178,180,188,190] end
			
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

		@discidFileIn = (@cmd_dc ? File.expand_path(@cmd_dc) : nil)
		@discidFileOut = (@cmd_df ? File.expand_path(@cmd_df) : nil)
		@acoustidFileIn = (@cmd_ac ? File.expand_path(@cmd_ac) : nil)
		@acoustidFileIn = (@cmd_af ? File.expand_path(@cmd_af) : nil)
		
		if @cmd_tok then @actoken = @cmd_tok end
	end
	
	
	
end
end
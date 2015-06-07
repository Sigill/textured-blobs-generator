#!/usr/bin/ruby

require "optparse"
require "ostruct"
require "escape"
require "fileutils"

class Integer
	N_BYTES = [42].pack("i").size
	N_BITS = N_BYTES * 8
	MAX = 2 ** (N_BITS - 2) - 1
	MIN = -MAX - 1
end

def check_command(command)
	begin
		`#{command}`
		return true
	rescue
		return false
	end
end

Rand = Random.new(Time.now.to_i)

params = OpenStruct.new
params.rb = "randomblob"
params.number = 10
params.size = 256

ARGV.options do |opts|
	opts.on( "-h", "--help", "Display this screen" ) do
		puts opts
		exit(0)
	end

	opts.on( "--rb PATH", "Path of the randomblob executable." ) { |p| params.rb = p }

	opts.on( "-n NUM", Integer, "Number of blobs to generate" ) do |n|
		abort("Number of blobs must be strictly positive.") if n <= 0
		params.number = n
	end

	opts.on( "-s INTEGER", Integer, "Size of the generated image. Default: #{params.size}." ) do |v|
		abort("The size must be a positive integer.") unless v > 0
		params.size = v
	end

	opts.on( "-o DIR", "The output folder" ) { |d| params.outdir = d }
end.parse!

abort("You must specify the number of blobs to generate.") if params.number.nil?
abort("You must specify the output directory.") if params.outdir.nil?
abort("Cannot run randomblob.") unless check_command("#{params.rb} -v")
abort("Cannot run convert. Install ImageMagick.") unless check_command("convert -version")

begin
	Dir.mkdir(params.outdir) unless Dir.exists?(params.outdir)
rescue
	abort "Cannot create \"#{params.output}\"."
end

1.upto(params.number) do |i|
	blob = File.join(params.outdir, "%03d" % i, "blob", "000000.png")
	FileUtils.mkdir_p File.dirname(blob)

	# Use http://www.fmwconcepts.com/imagemagick/randomblob/index.php
	command = Escape.shell_command [params.rb, "-S", Rand.rand(Integer::MAX).to_s,
	                                           "-o", params.size.to_s,
	                                           "-i", (params.size * 0.75).to_i.to_s,
	                                           "-l", (params.size * 0.08).to_i.to_s,
                                                   "-b", (params.size * 0.0625).to_i.to_s, blob]
	puts command
	`#{command}`

	command = Escape.shell_command ["convert", blob, "-negate", blob]
	`#{command}`

	puts "#{i} done"
end

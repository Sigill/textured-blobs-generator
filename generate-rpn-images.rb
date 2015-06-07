#!/usr/bin/env ruby

require "escape"
require "optparse"
require "ostruct"

params = OpenStruct.new
params.width = 512.to_s
params.height = 512.to_s
params.rpn = 'random_phase_noise'

optparse = ARGV.options do |opts|
	opts.on( "-h", "--help", "Display this help." ) do
		$stderr.puts opts
		exit(0)
	end

	opts.on( "--rpn PATH", "Path of the random_phase_noise executable." ) do |p|
		params.rpn = p
	end

	opts.on( "-s", "--seeds DIR", "The directory containing the images to be used as seeds (must be PNGs)." ) do |d|
		params.seeds = Dir.glob(File.join(d, "*.png")).sort
	end

	opts.on( "-x INTEGER", Integer, "The width of the output images (must be greater than the width of the seeds). Default: #{params.width}." ) do |v|
		abort("The width must be a positive integer.") unless v > 0
		params.width = v.to_s
	end

	opts.on( "-y INTEGER", Integer, "The height of the output images (must be greater than the height of the seeds). Default: #{params.height}." ) do |v|
		abort("The height must be a positive integer.") unless v > 0
		params.height = v.to_s
	end

	opts.on( "-o", "--output DIR", "The directory where generated images will be stored." ) do |d|
		params.output = d
	end
end
optparse.parse!

abort("No seeds provided.") if params.seeds.nil?
abort("No output dir provided.") if params.output.nil?

begin
	`#{params.rpn} -v`
rescue
	abort "Cannot run random_phase_noise."
end

begin
	Dir.mkdir(params.output) unless Dir.exists?(params.output)
rescue
	abort "Cannot create \"#{params.output}\"."
end

params.seeds.each do |seed|
	output = File.join(params.output, File.basename(seed))

	abort "#{output} already exists" if File.exists?(output)

	c = Escape.shell_command [params.rpn, '-x', params.width, '-y', params.height, seed, output]
	$stderr.puts c
	output = `#{c}`

	abort(output) unless $?.to_i == 0
end

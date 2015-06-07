#!/usr/bin/ruby

require "optparse"
require "yaml"
require "ostruct"
require "pathname"

params = OpenStruct.new

ARGV.options do |opts|
	opts.on( "-h", "--help", "Display this screen" ) { puts opts; exit(0) }

	opts.on( "-b", "--blobs DIR", "The folder containing the blobs." ) do |d|
		params.blobs_dir = d
		params.blobs = Dir.glob("#{d}/*").select { |fn| File.directory?(fn) }.map { |fn| File.basename fn }.sort
		abort("No blobs found in #{d}") if params.blobs.empty?
	end

	opts.on( "-t", "--textures DIR", "The folder containing the textures." ) do |d|
		params.textures_dir = d
		params.textures = Dir.glob("#{d}/*.{png,bmp}").sort.map { |t| File.basename(t) }
		abort("No textures found in #{d}") if params.textures.empty?
	end

	opts.on( "-n", "--number NUM", Integer, "Number of images to generate." ) do |n|
		abort("Number of images to generate must be greater than 0.") unless n > 0
		params.number = n
	end

	opts.on( "-c", "--count NUM", Integer, "Number of blobs per image." ) do |n|
		abort("Number of blobs must be greater than 0.") unless n > 0
		params.count = n
	end
end.parse!

abort("You must specify the blobs directory.") if params.blobs.nil?
abort("You must specify the textures directory.") if params.textures.nil?
abort("You must specify the number of images to generate.") if params.number.nil?
abort("You must specify the number of blobs per image.") if params.count.nil?
abort("There is not enough blobs in #{params.blobs_dir}.") if params.blobs.size < params.count
abort("There is not enough textures in #{params.textures_dir}.") if params.textures.size < params.count

dataset = {
	"blobs_dir" => Pathname.new(params.blobs_dir).realpath.to_s,
	"textures_dir" => Pathname.new(params.textures_dir).realpath.to_s,
	"count" => params.count,
	"configurations" => []
}

params.number.times do
	blobs = params.blobs.sample(params.count)

	textures = params.textures.sample(params.count + 1)
	background_texture = textures.shift

	composition = {
		"blobs" => blobs,
		"textures" => textures,
		"background_texture" => background_texture
	}

	dataset["configurations"].push composition
end

puts dataset.to_yaml

#!/usr/bin/ruby

require "fileutils"
require "optparse"
require "tmpdir"
require "escape"
require "ostruct"
require "yaml"

params = OpenStruct.new
ARGV.options do |opts|
	opts.on( "-h", "--help", "Display this screen" ) do
		puts opts
		exit 0
	end
	opts.on( "-d", "--dataset-description FILE", "The dataset description yaml file" ) { |d| params.dataset_description = d }
	opts.on( "-n", "--name NAME", "The learning set to import" ) { |n| params.ls_name = n }
	opts.parse!
end

abort("No dataset description provided.") if params.dataset_description.nil?
abort("No learning set name provided.") if params.ls_name.nil?

begin
	`convert -version`
rescue
	abort("Cannot run convert. Install ImageMagick.")
end

Outdir = File.dirname params.dataset_description

Dataset = YAML.load_file params.dataset_description

def learning_set(ls_dir, name)
	File.join(ls_dir, name, "000000.png")
end

def tile(tiles, out)
	FileUtils.mkdir_p File.dirname(out)
	`#{Escape.shell_command ["montage", *tiles, "-geometry", "+0+0", "-background", "black", out]}`
end

Dataset["configurations"].each_index { |conf_id|
	conf = Dataset["configurations"][conf_id]

	Dir.mktmpdir("/tmp/") { |tmp_dir|
		class0_tiles = []
		class1_tiles = []

		if(params.ls_name == "groundtruth") then
			output_name = "mask-groundtruth"

			blobs = conf["blobs"].map { |b| File.join(Dataset["blobs_dir"], b, "blob", "000000.png") }

			blobs.each_with_index { |b, i|
				class0_tiles.push b
				class1_tile = File.join(tmp_dir, "%03d_000000.png" % (i+1))
				class1_tiles.push class1_tile
				`#{Escape.shell_command ["convert", b, "-negate", class1_tile]}`
			}
		else
			output_name = params.ls_name

			learning_sets = conf["blobs"].map { |b| File.join(Dataset["blobs_dir"], b, params.ls_name) }
			learning_sets.each { |ls|
				class0_tiles.push learning_set(ls, "blob")
				class1_tiles.push learning_set(ls, "background")
			}
		end

		output_dir = File.join(Outdir, "%03d" % (conf_id+1), output_name)

		blobsize = `#{Escape.shell_command ["identify", "-format", "%wx%h", class0_tiles[0]]}`.strip
		black = File.join(tmp_dir, "black.png")
		`#{Escape.shell_command ["convert", "-size", blobsize, "pattern:gray0", black]}`

		class0_tiles.each_with_index do |t, i|
			ls_tiles = Array.new(Dataset["count"]) { |j| black }
			ls_tiles[i] = t
			tile(ls_tiles, learning_set(output_dir, "%03d" % (i+1)))
		end

		tile(class1_tiles, learning_set(output_dir, "255"))
	}
}

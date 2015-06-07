#!/usr/bin/ruby

require "fileutils"
require "optparse"
require "tmpdir"
require "escape"
require "ostruct"
require "yaml"

params = OpenStruct.new
ARGV.options do |opts|
	opts.on( "-h", "--help", "Display this screen." ) do
		puts opts
		exit 0
	end

	opts.on( "-d", "--dataset-description FILE", "The dataset description yaml file." ) { |d| params.dataset_description = d }
end.parse!

abort("No dataset description provided") if params.dataset_description.nil?

begin
	`convert -version`
rescue
	abort("Cannot run convert. Install ImageMagick.")
end

Outdir = File.dirname params.dataset_description

Dataset = YAML.load_file params.dataset_description

Dataset["configurations"].each_index do |conf_id|
	config_desc = Dataset["configurations"][conf_id]
	image_dir = File.join(Outdir, "%03d" % (conf_id+1), "image")

	FileUtils.mkdir_p image_dir

	Dir.mktmpdir("/tmp/") { |tmp_dir|
		textured_blobs = []

		# Texturize each blob (but not the background)
		Dataset["count"].times { |i|
			blob = File.join(Dataset["blobs_dir"], config_desc["blobs"][i], "blob", "000000.png")
			texture = File.join(Dataset["textures_dir"], config_desc["textures"][i])

			out = File.join(tmp_dir, "blob_%03d.png" % i)
			`#{Escape.shell_command ["composite", "-compose", "Multiply", "-tile", texture, blob, out]}`

			textured_blobs.push(out)
		}

		tiled_blobs_img = File.join(tmp_dir, "tiled_blobs.png")
		tiled_textured_blobs_img = File.join(tmp_dir, "tiled_textured_blobs.png")
		background_texture_img = File.join(tmp_dir, "background_texture.png")

		# Tiles the textured blobs
		`#{Escape.shell_command ["montage", *textured_blobs, "-geometry", "+0+0", "-background", "black", tiled_textured_blobs_img]}`
		# And the original blobs (creating a mask)
		`#{Escape.shell_command ["montage", *(config_desc["blobs"].map { |b| File.join(Dataset["blobs_dir"], b, "blob", "000000.png") }), "-geometry", "+0+0", "-background", "black", tiled_blobs_img]}`

		size = `#{Escape.shell_command ["identify", "-format", "%wx%h", tiled_textured_blobs_img]}`.strip

		# Creating a texture of the size of the composed image
		`#{Escape.shell_command ["convert", "-size", size, "tile:#{File.join(Dataset["textures_dir"], config_desc["background_texture"])}", background_texture_img]}`

		# Then composing textured blobs and background texture
		`#{Escape.shell_command ["composite", tiled_textured_blobs_img, background_texture_img, tiled_blobs_img, File.join(image_dir, "000000.png")]}`
	}
end

#!/usr/bin/ruby

require "fileutils"
require "optparse"
require "tmpdir"
require "escape"
require "ostruct"
require "yaml"

def gray_hex_value(value)
	h = "%02x" % value
	return "##{h}#{h}#{h}"
end

params = OpenStruct.new
ARGV.options do |opts|
	opts.on( "-h", "--help", "Display this screen" ) do
		puts opts
		exit 0
	end
	opts.on( "-d", "--dataset-description FILE", "The dataset description yaml file" ) { |d| params.dataset_description = d }
	opts.parse!
end

abort("No dataset description provided.") if params.dataset_description.nil?

begin
	`convert -version`
rescue
	abort("Cannot run convert. Install ImageMagick.")
end

Outdir = File.dirname params.dataset_description

Dataset = YAML.load_file params.dataset_description

Dataset["configurations"].each_index { |conf_id|
	config_desc = Dataset["configurations"][conf_id]
	groundtruth_dir = File.join(Outdir, "%03d" % (conf_id+1), "groundtruth")

	FileUtils.mkdir_p groundtruth_dir

	Dir.mktmpdir("/tmp/") { |tmp_dir|
		groundtruths = []
		Dataset["count"].times { |i|
			blob = File.join(Dataset["blobs_dir"], config_desc["blobs"][i], "blob", "000000.png")
			groundtruth = File.join(tmp_dir, "groundtruth_%03d.png" % (i+1))

			`#{Escape.shell_command ["convert", blob, "-fill", gray_hex_value(i+1), "-opaque", gray_hex_value(255), groundtruth]}`
			groundtruths.push groundtruth
		}

		groundtruth = File.join(groundtruth_dir, "000000.png")
		`#{Escape.shell_command ["montage", *groundtruths, "-geometry", "+0+0", "-background", "black", groundtruth]}`

		`#{Escape.shell_command ["convert", groundtruth, "-depth", "8", "-fill", gray_hex_value(255), "-opaque", gray_hex_value(0), groundtruth]}`
	}
}

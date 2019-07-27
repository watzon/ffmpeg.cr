require "./ffmpeg/extensions/*"
require "./ffmpeg/video"
require "./ffmpeg/transcoder"
require "./ffmpeg/encoding_options"

module FFMPEG
  @@ffmpeg_binary : String?

  @@ffprobe_binary : String?

  # Set the path of the ffmpeg binary.
  # Can be useful if you need to specify a path such as /usr/local/bin/ffmpeg
  def self.ffmpeg_binary=(bin)
    if bin.is_a?(String) && !File.executable?(bin)
      raise Errno.new("the ffmpeg binary, \'#{bin}\', is not executable", Errno::ENOENT)
    end
    @@ffmpeg_binary = bin
  end

  # Get the path to the ffmpeg binary, defaulting to 'ffmpeg'
  def self.ffmpeg_binary
    @@ffmpeg_binary ||= which("ffmpeg")
  end

  # Set the path of the ffprobe binary.
  # Can be useful if you need to specify a path such as /usr/local/bin/ffprobe
  def self.ffprobe_binary=(bin)
    if bin.is_a?(String) && !File.executable?(bin)
      raise Errno.new("the ffprobe binary, \'#{bin}\', is not executable", Errno::ENOENT)
    end
    @@ffprobe_binary = bin
  end

  # Get the path to the ffprobe binary, defaulting to 'ffprobe'
  def self.ffprobe_binary
    @@ffprobe_binary ||= which("ffprobe")
  end

  # Cross-platform way of finding an executable in the $PATH.
  def self.which(cmd)
    exts = ENV["PATHEXT"]? ? ENV["PATHEXT"].split(";") : [""]
    ENV["PATH"].split(':').each do |path|
      exts.each { |ext|
        exe = File.join(path, "#{cmd}#{ext}")
        return exe if File.executable?(exe)
      }
    end
    raise Errno.new("the #{cmd} binary could not be found in #{ENV["PATH"]}", Errno::ENOENT)
  end
end

encoding_options = FFMPEG::EncodingOptions.new({
  video_codec: "libx264", frame_rate: 10, resolution: "320x240", video_bitrate: 300, video_bitrate_tolerance: 100,
  aspect: 1.333333, keyframe_interval: 90, x264_vprofile: "high", x264_preset: "slow",
  audio_codec: "aac", audio_bitrate: 32, audio_sample_rate: 22050, audio_channels: 1, threads: 2
})
trans = FFMPEG::Transcoder.new("~/Downloads/xvide.mp4", "~/Downloads/transcoded.mp4", encoding_options)
puts trans.command.join(" ")

require "big"
require "uri"
require "json"
require "http/client"
require "./stream"

module FFMPEG
  class Video
    UNSUPPORTED_CODEC_PATTERN = /^Unsupported codec with id (\d+) for input stream (\d+)$/

    @path : String

    # General
    getter path : String
    getter duration : Time::Span
    getter time : Time::Span
    getter bitrate : Int32?
    getter rotation : Int32?
    getter creation_time : Time?

    # Video
    getter video_streams : Array(VideoStream)
    getter video_stream : VideoStream?
    getter video_codec : String?
    getter video_bitrate : Int32?
    getter colorspace : String?
    getter width : Int32?
    getter height : Int32?
    getter sar : String?
    getter dar : String?
    getter frame_rate : BigRational?

    # Audio
    getter audio_streams : Array(AudioStream)
    getter audio_stream : AudioStream?
    getter audio_codec : String?
    getter audio_bitrate : Int32?
    getter audio_sample_rate : Int32?
    getter audio_channels : Int32?
    getter audio_channel_layout : String?
    getter audio_tags : Hash(String, String)?

    # Metadata
    getter container : Array(String)
    getter metadata : JSON::Any
    getter format_tags : JSON::Any

    # Creates a new `Video` object from a path
    def initialize(path)
      @path = path = File.expand_path(path, __DIR__)

      if remote?
        raise "Remote files are not yet supported"
      end

      command = FFMPEG.ffprobe_binary
      args = ["-i", path, "-hide_banner", "-loglevel", "fatal", "-show_error", "-show_format", "-show_streams", "-show_programs", "-show_chapters", "-show_private_data", "-print_format", "json"]
      std_out = IO::Memory.new
      std_err = IO::Memory.new

      proc = Process.new(command, args, output: std_out, error: std_err)
      status = proc.wait

      if status.exit_code < 0
        raise proc.error?.to_s
      end

      @metadata = begin
        JSON.parse(std_out.to_s)
      rescue JSON::ParseException
        raise "Could not parse output from FFProbe:\n#{std_out.to_s}"
      end

      if error = @metadata["error"]?
        raise error["message"].to_s
      end

      @video_streams = @metadata["streams"].as_a.select { |stream| stream["codec_type"] == "video" }.map { |s| VideoStream.from_json(s.to_json) }
      @audio_streams = @metadata["streams"].as_a.select { |stream| stream["codec_type"] == "audio" }.map { |s| AudioStream.from_json(s.to_json) }

      @container = @metadata["format"]["format_name"].to_s.split(',')

      duration = @metadata["format"]["duration"].to_s.to_f
      @duration = Time::Span.new(nanoseconds: (duration * 1000).to_i)

      start_time = @metadata["format"]["start_time"].to_s.to_f
      @time = Time::Span.new(nanoseconds: (start_time * 1000).to_i)

      @format_tags = @metadata["format"]["tags"]

      @creation_time = if creation_time = @format_tags["creation_time"]?
                         begin
                          Time::Format::RFC_3339.parse(creation_time.to_s)
                         rescue ArgumentError
                           nil
                         end
                       else
                         nil
                       end

      @bitrate = @metadata["format"]["bitrate"]?.try &.to_s.to_i

      @video_stream = video_stream = video_streams.try &.first
      unless video_stream.nil?
        @video_codec = video_stream.codec_name
        @colorspace = video_stream.pix_fmt
        @width = video_stream.width
        @height = video_stream.height
        @video_bitrate = video_stream.bit_rate.to_i
        @sar = video_stream.sample_aspect_ratio
        @dar = video_stream.display_aspect_ratio

        @frame_rate = unless video_stream.avg_frame_rate == "0/0"
                        numerator, denominator = video_stream.avg_frame_rate.split('/')
                        BigRational.new(numerator.to_i64, denominator.to_i64)
                      else
                        nil
                      end

        @rotation = if video_stream.tags && video_stream.tags.has_key?("rotate")
                      video_stream.tags["rotate"].to_i
                    else
                      nil
                    end
      end

      @audio_stream = audio_stream = audio_streams.try &.first
      unless audio_stream.nil?
        @audio_channels = audio_stream.channels.try &.to_i
        @audio_codec = audio_stream.codec_name
        @audio_sample_rate = audio_stream.sample_rate.to_i
        @audio_bitrate = audio_stream.bit_rate.try &.to_i
        @audio_channel_layout = audio_stream.channel_layout
        @audio_tags = audio_stream.tags
      end
    end

    def width
      rotation.nil? || rotation == 180 ? @width : @height
    end

    def height
      rotation.nil? || rotation == 180 ? @height : @width
    end

    def resolution
      unless width.nil? || height.nil?
        "#{width}x#{height}"
      end
    end

    def calculated_aspect_ratio
      aspect_from_dar || aspect_from_dimensions
    end

    def calculated_pixel_aspect_ratio
      aspect_from_sar || 1
    end

    def size
      File.size(@path)
    end

    def audio_channel_layout
      @audio_channel_layout || case(audio_channels)
                                 when 1
                                   "mono"
                                 when 2
                                   "stereo"
                                 when 6
                                   "5.1"
                                 else
                                   "unknown"
                               end
    end

    def remote?
      !URI.parse(@path).relative?
    end

    def local?
      !remote?
    end

    protected def aspect_from_dar
      calculate_aspect(dar)
    end

    protected def aspect_from_sar
      calculate_aspect(sar)
    end

    protected def calculate_aspect(ratio)
      return nil unless ratio
      w, h = ratio.split(":")
      return nil if w == "0" || h == "0"
      @rotation.nil? || (@rotation == 180) ? (w.to_f / h.to_f) : (h.to_f / w.to_f)
    end

    protected def aspect_from_dimensions
      return nil unless width && height
      aspect = width.not_nil!.to_f / height.not_nil!.to_f
      aspect.nan? ? nil : aspect
    end
  end
end

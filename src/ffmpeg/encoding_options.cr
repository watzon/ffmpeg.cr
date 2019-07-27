module FFMPEG
  class EncodingOptions < Hash(String, String)

    def initialize(options)
      super()
      merge!(options.to_h.transform_keys(&.to_s).transform_values(&.to_s))
    end

    def params_order(k)
      if k =~ /watermark$/
        0
      elsif k =~ /watermark/
        1
      elsif k =~ /codec/
        2
      elsif k =~ /preset/
        3
      else
        4
      end
    end

    def to_a
      params = [] of String

      # codecs should go before the presets so that the files will be matched successfully
      # all other parameters go after so that we can override whatever is in the preset
      keys.sort_by{|k| params_order(k) }.each do |key|

        value = self[key]?
        next if value.nil?

        params += case key
        when "aspect"
          calculate_aspect? ? convert_aspect(calculate_aspect) : [] of String
        when "video_codec"
          ["-vcodec", value.to_s]
        when "frame_rate"
          ["-r", value.to_s]
        when "resolution"
          ["-s", value.to_s]
        when "video_bitrate"
          ["-b:v", k_format(value.to_s)]
        when "audio_codec"
          ["-acodec", value.to_s]
        when "audio_bitrate"
          ["-b:a", k_format(value.to_s)]
        when "audio_sample_rate"
          ["-ar", value.to_s]
        when "audio_channels"
          ["-ac", value.to_s]
        when "video_max_bitrate"
          ["-maxrate", k_format(value.to_s)]
        when "video_min_bitrate"
          ["-minrate", k_format(value.to_s)]
        when "buffer_size"
          ["-bufsize", k_format(value.to_s)]
        when "video_bitrate_tolerance"
          ["-bt", k_format(value.to_s)]
        when "threads"
          ["-threads", value.to_s]
        when "target"
          ["-target", value.to_s]
        when "duration"
          ["-t", value.to_s]
        when "video_preset"
          ["-vpre", value.to_s]
        when "audio_preset"
          ["-apre", value.to_s]
        when "file_preset"
          ["-fpre", value.to_s]
        when "keyframe_interval"
          ["-g", value.to_s]
        when "seek_time"
          ["-ss", value.to_s]
        when "screenshot"
          convert_screenshot(value)
        when "quality"
          ["-q:v", value.to_s]
        when "vframes"
          ["-vframes", value.to_s]
        when "x264_vprofile"
          ["-vprofile", value.to_s]
        when "x264_preset"
          ["-preset", value.to_s]
        when "watermark"
          ["-i", value.to_s]
        else
          raise "Unsupported option #{key}"
        end
      end

      params.compact
    end

    def width
      self["resolution"].split("x").first.to_i rescue nil
    end

    def height
      self["resolution"].split("x").last.to_i rescue nil
    end

    private def supports_option?(option)
      option = "convert_#{option}"
      private_methods.includes?(option)
    end

    private def convert_aspect(value)
      ["-aspect", value.to_s]
    end

    private def calculate_aspect
      width, height = self["resolution"].split("x")
      width.to_f / height.to_f
    end

    private def calculate_aspect?
      self["aspect"]? && self["resolution"]?
    end

    private def convert_screenshot(value)
      result = [] of String
      unless self["vframes"]
        result << "-vframes"
        result << "1"
      end
      result << "-f"
      result << "image2"
      value ? result : [] of String
    end

    private def convert_watermark_filter(value)
      position = value["position"]
      padding_x = value["padding_x"] || "10"
      padding_y = value["padding_y"] || "10"
      case position.to_s
        when "LT"
          ["-filter_complex", "scale=#{self["resolution"]},overlay=x=#{padding_x}:y=#{padding_y}"]
        when "RT"
          ["-filter_complex", "scale=#{self["resolution"]},overlay=x=main_w-overlay_w-#{padding_x}:y=#{padding_y}"]
        when "LB"
          ["-filter_complex", "scale=#{self["resolution"]},overlay=x=#{padding_x}:y=main_h-overlay_h-#{padding_y}"]
        when "RB"
          ["-filter_complex", "scale=#{self["resolution"]},overlay=x=main_w-overlay_w-#{padding_x}:y=main_h-overlay_h-#{padding_y}"]
      end
    end

    private def k_format(value)
      value.to_s.includes?("k") ? value : "#{value}k"
    end
  end
end

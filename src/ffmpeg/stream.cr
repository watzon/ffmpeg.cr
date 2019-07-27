require "json"
require "big"

module FFMPEG
  class Stream
    include JSON::Serializable

    getter index : Int32

    getter codec_name : String

    getter codec_long_name : String

    getter codec_type : String

    getter codec_time_base : String

    getter codec_tag_string : String

    getter codec_tag : String

    getter r_frame_rate : String

    getter avg_frame_rate : String

    getter time_base : String

    getter start_pts : Int32

    getter start_time : String

    getter duration_ts : Int32

    getter duration : String

    getter bit_rate : String

    getter nb_frames : String

    getter disposition : Stream::Disposition

    getter tags : Hash(String, String)

    class Disposition
      include JSON::Serializable

      getter default : Int32

      getter original : Int32

      getter comment : Int32

      getter lyrics : Int32

      getter karaoke : Int32

      getter forced : Int32

      getter hearing_impared : Int32?

      getter visual_impared : Int32?

      getter clean_effects : Int32

      getter attached_pic : Int32

      getter timed_thumbnails : Int32
    end
  end

  class VideoStream < Stream
    getter width : Int32

    getter height : Int32

    getter bits_per_raw_sample : String

    getter has_b_frames : Int32

    getter pix_fmt : String

    getter level : Int32

    getter chroma_location : String

    getter refs : Int32

    getter is_avc : String

    getter nal_length_size : String

    getter sample_aspect_ratio : String?

    getter display_aspect_ratio : String?
  end

  class AudioStream < Stream
    getter profile : String

    getter channels : Int32

    getter sample_rate : String

    getter sample_fmt : String?

    getter channel_layout : String?
  end
end

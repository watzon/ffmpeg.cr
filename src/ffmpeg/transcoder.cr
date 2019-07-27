module FFMPEG
  class Transcoder
    @video : FFMPEG::Video?

    @errors : Array(String)

    @output_file : String

    getter command : Array(String)

    getter input : String

    getter raw_options : Hash(String, String | Array(String))

    getter transcoder_options : Hash(String, String | Array(String))

    class_property timeout : Int32 = 30

    def initialize(
      input : Video | String,
      output_file : String,
      options = EncodingOptions.new,
      transcoder_options = {} of String => String | Array(String)
    )

      if input.is_a?(FFMPEG::Video)
        @video = input
        @input = input.path
      else
        @input = input
      end
      @output_file = output_file

      @raw_options, @transcoder_options = optimize_screenshot_parameters(options, transcoder_options)

      @errors = [] of String | Array(String)

      apply_transcoder_options

      if tinput = @transcoder_options["input"]?
        @input = tinput
      end

      input_options = @transcoder_options["input_options"] || [] of String | Array(String)
      iopts = [] of String | Array(String)

      if input_options.is_a?(Array)
        iopts += input_options
      else
        input_options.to_h.each { |(k, v)| iopts += ["-" + k.to_s, v] }
      end

      @command = [FFMPEG.ffmpeg_binary, "-y"] + iopts + ["-i", @input] + options.to_a + [@output_file]
    end

    def encoding_succeeded?
      @errors.empty?
    end

    def encoded
      @encoded ||= Movie.new(@output_file) if File.exist?(@output_file)
    end

    def timeout
      self.class.timeout
    end

    private def apply_transcoder_options(options)
      # if true runs #validate_output_file
      options["validate"] = options.fetch("validate", true)

      return if @movie.nil? || @movie.calculated_aspect_ratio.nil?
      case options["preserve_aspect_ratio"]
      when "width"
        new_height = @raw_options.width / @movie.calculated_aspect_ratio
        new_height = new_height.ceil.even? ? new_height.ceil : new_height.floor
        new_height += 1 if new_height.odd? # needed if new_height ended up with no decimals in the first place
        @raw_options["resolution"] = "#{@raw_options.width}x#{new_height}"
      when "height"
        new_width = @raw_options.height * @movie.calculated_aspect_ratio
        new_width = new_width.ceil.even? ? new_width.ceil : new_width.floor
        new_width += 1 if new_width.odd?
        @raw_options["resolution"] = "#{new_width}x#{@raw_options.height}"
      end

      options
    end

    private def optimize_screenshot_parameters(options : EncodingOptions, transcoder_options : (Array | Hash | EncodingOptions)?)
      raw_options, input_seek_time = screenshot_seek_time(options)
      screenshot_to_transcoder_options(input_seek_time, transcoder_options)

      {raw_options, transcoder_options}
    end

    private def screenshot_seek_time(options : Array | Hash)
      # Returns any seek_time for the screenshot and removes it from the options
      # such that the seek time can be moved to an input option for improved FFMPEG performance
      case options
      when Array
        seek_time_idx = options.index("-seek_time") unless options.index("-screenshot").nil?
        unless seek_time_idx.nil?
          options.delete_at(seek_time_idx) # delete 'seek_time'
          input_seek_time = options.delete_at(seek_time_idx).to_s # fetch the seek value
        end
        result = {options, input_seek_time}
      else
        raw_options = EncodingOptions.new(options)
        input_seek_time = raw_options.delete("seek_time").to_s if raw_options["screenshot"]?
        result = {raw_options, input_seek_time}
      end
      result
    end

    private def screenshot_to_transcoder_options(seek_time : String?, transcoder_options : Hash | EncodingOptions)
      return if seek_time.nil? || seek_time.empty?

      input_options = [] of String
      # remove ss from input options because we're overriding from seek_time
      if input_options.is_a?(Array)
        fi = input_options.index("-ss").try &.to_i
        if fi.nil?
          input_options.concat(["-ss", seek_time])
        else
          input_options[fi + 1] = seek_time
        end
      else
        input_options["ss"] = seek_time
      end

      transcoder_options["input_options"] = input_options
    end
  end
end

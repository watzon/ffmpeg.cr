struct Int
  class HexConverter
    def self.from_json(value : JSON::PullParser)
      value.read_string.to_i(16)
    end

    def self.to_json(value, json : JSON::Builder)
      json.string(value.to_s(16))
    end
  end
end

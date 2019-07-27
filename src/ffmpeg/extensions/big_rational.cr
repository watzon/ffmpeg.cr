struct BigRational < Number
  class StringConverter
    def self.from_json(value : JSON::PullParser)
      numerator, denominator = value.read_string.split('/')
      BigRational.new(numerator.to_i64, denominator.to_i64)
    end

    def self.to_json(value, json : JSON::Builder)
      json.string("#{value.numerator}/#{value.denominator}")
    end
  end
end

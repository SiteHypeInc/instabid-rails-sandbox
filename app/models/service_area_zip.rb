# TEA-345: read-only registry of the 5 service-area zips used to source
# regional HD pricing via BigBox. Backed by config/service_area_zips.yml.
#
# Not an ActiveRecord model — just a Struct + class-level loader so callers
# can ask `ServiceAreaZip.zips`, `ServiceAreaZip.codes`, or `.find("98101")`.
class ServiceAreaZip
  CONFIG_FILE = Rails.root.join("config", "service_area_zips.yml")

  Entry = Struct.new(:zip, :city, :state, :region, keyword_init: true) do
    def to_s = zip
  end

  class << self
    def zips
      @zips ||= load_zips
    end

    def codes
      zips.map(&:zip)
    end

    def find(zip_code)
      zips.find { |z| z.zip == zip_code.to_s }
    end

    def reload!
      @zips = nil
      zips
    end

    private

    def load_zips
      raise "service_area_zips.yml missing at #{CONFIG_FILE}" unless File.exist?(CONFIG_FILE)

      data = YAML.load_file(CONFIG_FILE)
      Array(data["zips"]).map do |entry|
        Entry.new(
          zip:    entry["zip"].to_s,
          city:   entry["city"],
          state:  entry["state"],
          region: entry["region"]
        )
      end.freeze
    end
  end
end

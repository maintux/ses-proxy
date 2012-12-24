require 'yaml'

module SesProxy
  class Conf
    def self.get
      YAML.load_file(File.join(ENV["HOME"],".ses-proxy","ses-proxy.yml"))
    end
  end
end
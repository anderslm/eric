require "getoptlong"
require "net/http"
require "rexml/document"
require "singleton"

class CommandLine < GetoptLong
    include Singleton
    attr_reader :environment

    def initialize
        super
            [ "--environment", "-E", GetoptLong::REQUIRED_ARGUMENT ]

        @environment = "paludis:ric"
        each do | opt, arg |
            case opt
            when "--environment"
                @environtment = arg
            end
        end
    end
end

class RemoteId
    attr_accessor :type, :value, :versions
    def initialize(type, value)
        @type = type
        @value = value
        @versions = Array.new
    end

    def add_version(plaintext)
        versions << RemoteVersion.new(plaintext)
    end

    def find_versions()
        case type
            when "freshmeat"
                uri = URI("http://freecode.com/projects/#{value}/releases.xml?auth_code=iZGCkMK7nxw6nhbArwN")
                best_version = nil
                xml = Net::HTTP.get_response(uri).body
                doc = REXML::Document.new(xml)
                doc.elements.each("releases/release") do |release|
                    version = release.elements["version"].get_text.to_s.strip
                    add_version(version)
                end
        end
    end
end

class RemoteVersion
    attr_accessor :plaintext
    def initialize(plaintext)
        @plaintext = plaintext
    end

    def spec
        begin
            return VersionSpec.new(plaintext)
        rescue
            return "Not available"
        end
    end
end

class Package
    attr_accessor :name, :remotes
    def initialize(paludis_package)
        @name = paludis_package.name.to_s
        @remotes = Array.new
    end

    def add_remote(remote)
        @remotes << remote
    end
end


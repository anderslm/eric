require "getoptlong"
require "net/http"
require "rexml/document"
require "singleton"
require "Paludis"

include Paludis

class CommandLine < GetoptLong
    include Singleton
    attr_reader :environment, :cache_file, :drop_cache

    def initialize
        super( 
            [ "--environment", "-E", GetoptLong::REQUIRED_ARGUMENT ],
            [ "--cache-file", GetoptLong::REQUIRED_ARGUMENT ],
            [ "--drop-cache", GetoptLong::NO_ARGUMENT ] )

        @environment = "paludis:ric"
        @cache_file = "packages.ric"
        @drop_cache = false
        each do | opt, arg |
            case opt
            when "--environment"
                @environtment = arg
            when "--cache-file"
                @cache_file = arg
            when "--drop-cache"
                @drop_cache = true
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
    attr_accessor :name, :remotes, :best_version_in_each_slot
    def initialize(paludis_package)
        @name = paludis_package.name.to_s
        @remotes = Array.new
        @best_version_in_each_slot = Hash.new
    end

    def add_remote(remote)
        @remotes << remote
    end

    def find_best_version_in_each_slot
        env = EnvironmentFactory.instance.create(CommandLine.instance.environment)

        best_versions = env[Selection::BestVersionInEachSlot.new(Generator::Matches.new(parse_user_package_dep_spec(@name, env, []), nil, []))]
        best_versions.each do |package|
            package.each_metadata do |meta| 
                if meta.human_name == "Slot"
                    best_version_in_each_slot[meta.parse_value] = package.version.to_s
                    break
                end
            end
        end
    end
end


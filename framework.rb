require "getoptlong"
require "rubygems"
require "json/ext"
require "net/http"
require "net/https"
require "rexml/document"
require "singleton"
require "Paludis"

include Paludis

:report_console

$matching_patterns = Hash.new
file = File.new("matching_patterns.conf", "r")

while (line = file.gets)
    key_value = line.split(" ")

    $matching_patterns[key_value[0]] = key_value[1]
end
file.close

class CommandLine < GetoptLong
    include Singleton
    attr_reader :environment, :cache_file, :drop_cache, :keep_cache, :report_type

    def initialize
        super( 
            [ "--environment", "-E", GetoptLong::REQUIRED_ARGUMENT ],
            [ "--log-level", GetoptLong::REQUIRED_ARGUMENT ],
            [ "--cache-file", GetoptLong::REQUIRED_ARGUMENT ],
            [ "--keep-cache", GetoptLong::NO_ARGUMENT ],
            [ "--drop-cache", GetoptLong::NO_ARGUMENT ],
            [ "--type", GetoptLong::REQUIRED_ARGUMENT ] )

        @environment = ""
        @cache_file = "packages.yaml"
        @drop_cache = false
        @keep_cache = false
        @report_type = :report_console
        each do | opt, arg |
            case opt
            when "--environment"
                @environtment = arg
            when "--log-level"
                case arg
                when "debug"
                    Log.instance.log_level = LogLevel::Debug
                when "qa"
                    Log.instance.log_level = LogLevel::Qa
                when "silent"
                    Log.instance.log_level = LogLevel::Silent
                when "warning"
                    Log.instance.log_level = LogLevel::Warning
                else
                    puts "Log level '" + arg + "' does not exists. Specify one of: debug, qa, silent or warning."
                end
            when "--type"
                case arg
                when "console"
                    @report_type = :report_console
                else
                   puts "Report type '" + arg + "' does not exists. Specify one of: console."
                end
            when "--cache-file"
                @cache_file = arg
            when "--drop-cache"
                @drop_cache = true
            when "--keep-cache"
                @keep_cache = true
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
        url = nil

        begin
            case type
            when "freecode"
                url = "http://freecode.com/projects/#{value}/releases.xml?auth_code=iZGCkMK7nxw6nhbArwN"
                uri = URI(url)
                xml = Net::HTTP.get_response(uri).body
                doc = REXML::Document.new(xml)
                doc.elements.each("releases/release") do |release|
                    version = release.elements["version"].get_text.to_s.strip
                    add_version(version)
                end
            when "cpan"
                url = "http://api.metacpan.org/release/#{value}"
                uri = URI(url)
                json = JSON.parse(Net::HTTP.get_response(uri).body)
                if json != nil
                    version = json["version"]
                    if version != nil
                        add_version(version.strip)
                    end
                end
            when "launchpad"
                url = "https://api.launchpad.net/1.0/#{value}/releases"
                uri = URI(url)
                http = Net::HTTP.new(uri.host, uri.port)
                http.use_ssl = true
                http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                request = Net::HTTP::Get.new(uri.request_uri)
                json = JSON.parse(http.request(request).body)
                if json != nil
                    json["entries"].each do |entry|
                        version = entry["version"]
                        if version != nil
                            add_version(version.strip)
                        end
                    end
                end
            when "pypi"
                url = "http://pypi.python.org/pypi?:action=json&name=#{value}"
                uri = URI(url)
                json = JSON.parse(Net::HTTP.get_response(uri).body)
                if json != nil
                    info = json["info"]
                    if info != nil
                        if info["version"] != nil
                            add_version(info["version"].strip)
                        end
                    end
                end
            end
        rescue URI::InvalidURIError
            puts "The URI '#{url}' is not valid. Skipping."
        rescue Exception
            puts "The remote version could not be fetched. Skipping."
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
            return VersionSpec.new("0")
        end
    end
end

class Package
    attr_accessor :name, :remotes, :best_version_in_each_slot, :best_remote_version_in_each_slot, :matching_pattern
    def initialize(paludis_package)
        @name = paludis_package.name.to_s
        @remotes = Array.new
        @best_version_in_each_slot = Hash.new
        @best_remote_version_in_each_slot = Hash.new
        @matching_pattern = $matching_patterns[@name]
    end

    def add_remote(remote)
        @remotes << remote
    end

    def validate_version(version)
        if @matching_pattern == nil
            return version
        end

        return version.match(@matching_pattern).to_s
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
        best_version_in_each_slot.each_pair do |slot,value|
            remotes.each do |remote|
                remote.versions.each do |version|
                    version_string = validate_version(version.spec.to_s)
                    if !version.spec
                        version_string = validate_version(version.plaintext)
                    end
                    version.plaintext = version_string

                    if version_string and version_string != ""
                        if version_string.start_with?(slot)
                            if best_remote_version_in_each_slot[slot] == nil or
                                VersionSpec.new(best_remote_version_in_each_slot[slot]) < version.spec
                                best_remote_version_in_each_slot[slot] = version_string
                            end
                        else
                            new_slot = 
                                if slot != "0"
                                    version.spec.to_s[0, slot.length]
                                else
                                    new_slot = "0"
                                end
                            if best_remote_version_in_each_slot[new_slot] == nil or
                                VersionSpec.new(best_remote_version_in_each_slot[new_slot]) < version.spec
                                best_remote_version_in_each_slot[new_slot] = version_string
                            end
                        end
                    end
                end
            end
        end
    end
end

require "net/http"
require "rexml/document"
require "Paludis"
require "yaml"

include Paludis

EnvironmentSpec = ":ric"
OutputDir = "./output"
env = EnvironmentFactory.instance.create(EnvironmentSpec)

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

puts "Collecting all packages..."
all_packages = env[Selection::BestVersionOnly.new(Generator::All.new)]
packages = 
    if File.size? "packages.ric"
        YAML::load(File.read("packages.ric"))
    else
        Array.new
    end
i = 0
reset_line = "\r\e[0K"

all_packages.each do |fetched_package|
    print reset_line + "Checking #{i.to_s} of #{all_packages.length.to_s}. Found #{packages.length.to_s} candidates"
    $stdout.flush
    if packages.select{|p| p.name == fetched_package.name}.first == nil
        package = Package.new(fetched_package)
        has_remote = false
        fetched_package.each_metadata do |meta|
            if meta.human_name == "Remote IDs"
                has_remote = true
                meta.parse_value.each do |val|
                    values = val.to_s.split(":")
                    package.add_remote(RemoteId.new(values[0], values[1]))
                    package.remotes.last.find_versions
                end
            end
        end
        if has_remote
            packages << package
        end
        File.open("packages.ric", "w") do |file|
            file.puts packages.to_yaml
        end
    end
    i += 1
end
=begin
packages.each do |package|
    puts "#{package.name}-#{package.version}: "
    package.remotes.each do |remote|
        puts "#{remote.type}:#{remote.value}\n"
    end
end
=end
puts "\nNumber of packages: #{packages.count}"


require "Paludis"
require "yaml"

require "framework"
require "eric-report-console"

include Paludis

def eric_report()
    puts "Generating report..."

    packages = YAML::load(File::read(CommandLine.instance.cache_file))
    packages_with_updates = Array.new
  
    packages.each do |package|
        best_slot = "0"
        package.best_version_in_each_slot.each do |slot,version|
            remote_version = package.best_remote_version_in_each_slot[slot]
            if remote_version != nil and VersionSpec.new(remote_version) > VersionSpec.new(version) 
                packages_with_updates << package
            end
            if VersionSpec.new(best_slot) < VersionSpec.new(slot)
                best_slot = slot
            end
        end
        package.best_remote_version_in_each_slot.each do |slot,version|
            if package.best_version_in_each_slot[slot] == nil and slot > best_slot
                packages_with_updates << package unless packages_with_updates.include?(package)
            end
        end
    end

    case CommandLine.instance.report_type
    when :report_console
        eric_report_console(packages_with_updates)
    end
end

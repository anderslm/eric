require "framework"

require "yaml"

def ric_collect(env)
    puts "Collecting all packages..."

    # Get all packages from the current environment.
    all_packages = env[Selection::BestVersionOnly.new(Generator::All.new)]
    # Load the cache or create new collection if none.
    packages = 
        if File.size? CommandLine.instance.cache_file and not CommandLine.instance.drop_cache
            YAML::load(File.read(CommandLine.instance.cache_file))
        else
            Array.new
        end
    i = 0
    # Used to write on same line each time.
    reset_line = "\r\e[0K"

    begin
        # Go through each package.
        all_packages.each do |fetched_package|
            print reset_line + "Checking #{i.to_s} of #{all_packages.length.to_s}. Found #{packages.length.to_s} candidates"
            $stdout.flush
            # Only proceed if package is not already handled.
            if packages.select{|p| p.name == fetched_package.name}.first == nil
                package = Package.new(fetched_package)
                has_remote = false
                # Search through all metadata to find any remote ids.
                fetched_package.each_metadata do |meta| 
                    if meta.human_name == "Remote IDs"
                        has_remote = true
                        meta.parse_value.each do |val|
                            # Handle the remote and find all versions from it.
                            values = val.to_s.split(":")
                            package.add_remote(RemoteId.new(values[0], values[1]))
                            package.remotes.last.find_versions
                            package.find_best_version_in_each_slot
                        end
                        break
                    end
                end
                if has_remote
                    packages << package
                end
            end
            i += 1
        end
    ensure
        puts "\n\nWriting cache to file. Don't interupt this!\n\n"
        # Write cache.
        File.open(CommandLine.instance.cache_file, "w") do |file|
            file.puts packages.to_yaml
        end
    end
end


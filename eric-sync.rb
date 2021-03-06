require "date"
require "yaml"

require "framework"

def eric_sync(env, target)
    puts "Collecting all packages..."

    # Check for modification time and drop cache if neccesary.
    if File::exists? CommandLine.instance.cache_file and 
        ((File::mtime(CommandLine.instance.cache_file) < Time.now - (7 * (60*60*24)) and 
        not CommandLine.instance.keep_cache ) or CommandLine.instance.drop_cache)
        File.delete(CommandLine.instance.cache_file)
    else
        puts "Using cache file '" + CommandLine.instance.cache_file + "'."
    end

    all_packages = 
        if target 
            env[Selection::BestVersionOnly.new(Generator::Matches.new(Paludis::parse_user_package_dep_spec(target, env, [ :allow_wildcards ]), nil, []))]
        else
            # Get all packages from the current environment.
            env[Selection::BestVersionOnly.new(Generator::All.new)]
        end

    # Load the cache or create new collection if none.
    packages = 
        if File.size? CommandLine.instance.cache_file
            YAML::load(File::read(CommandLine.instance.cache_file))
        else
            Array.new
        end
    i = 0
    # Used to write on same line each time.
    reset_line = "\r\e[0K"

    begin

        # Go through each package.
        all_packages.each do |fetched_package|
            i += 1
        text = reset_line + "Checking #{i.to_s} of #{all_packages.length.to_s}. Found #{packages.length.to_s} candidate(s)..."
            print text
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
            print text
            $stdout.flush
        end
    ensure
        puts "\n\nWriting cache to file. Don't interupt this!\n\n"
        # Write cache.
        File.open(CommandLine.instance.cache_file, "w") do |file|
            file.puts packages.to_yaml
        end
    end
end

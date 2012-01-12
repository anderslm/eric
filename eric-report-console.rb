require "Paludis"

include Paludis

$length = 80
:left
:center

def print_line(content = "", align = :center, side_char = "+", fill_char = "-")
    length = $length
    length -= side_char.length * 2
    length -= content.length
    case align
    when :center
        left_hand_side = (length / 2).floor
        right_hand_side = (length / 2).floor
    when :left
        left_hand_side = 0
        right_hand_side = length
    end
    left_hand_line = ""
    right_hand_line = ""

    (0...left_hand_side).each do |i|
        left_hand_line += fill_char
    end

    (0...right_hand_side).each do |i|
        right_hand_line += fill_char
    end
    
    output = side_char + left_hand_line + content + right_hand_line + side_char

    while output.length < $length do
        right_hand_line += fill_char
        output = side_char + left_hand_line + content + right_hand_line + side_char
    end

    puts output
end

def eric_report_console(env, packages)
    puts packages.length.to_s + " package(s) needs updating."
    packages.each do |package|
        print_line(package.name)
        package.best_version_in_each_slot.each do |slot, local_version|
            repository = ""
            local_packages = env[Selection::AllVersionsSorted.new(Generator::Matches.new(parse_user_package_dep_spec("=" + package.name + "-" + local_version, env, []), nil, []))]
            local_packages.each do |local_package|
                if not local_package.name.to_s.include?("::installed")
                    repository = local_package.repository_name 
                end
            end
            remote_version = package.best_remote_version_in_each_slot[slot]
            if remote_version != nil
                print_line("::" + repository + "    " + local_version + " {:" + slot + "} -> " + remote_version, :left, "|", " ")
            end
        end
        print_line()
        puts "\n\n"
    end
    puts packages.length.to_s + " package(s) needs updating."
end

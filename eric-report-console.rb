def print_line(content = "", side_char = "+", fill_char = "-")
    length = 40
    length -= side_char.length * 2
    length -= content.length
    left_hand_side = (length / 2).floor
    right_hand_side = (length / 2).floor
    left_hand_line = ""
    right_hand_line = ""

    (0...left_hand_side).each do |i|
        left_hand_line += fill_char
    end

    (0...right_hand_side).each do |i|
        right_hand_line += fill_char
    end
    
    output = side_char + left_hand_line + content + right_hand_line + side_char

    while output.length < 40 do
        right_hand_line += fill_char
        output = side_char + left_hand_line + content + right_hand_line + side_char
    end

    puts output
end

def eric_report_console(packages)
    puts packages.length.to_s + " package(s) needs updating."
    packages.each do |package|
        print_line(package.name)
        package.best_version_in_each_slot.each do |slot, local_version|
            remote_version = package.best_remote_version_in_each_slot[slot]
            if remote_version != nil
                print_line("Slot " + slot + ": " + local_version + " --> " + remote_version, "|", " ")
            end
        end
        print_line()
        puts "\n\n"
    end
    puts packages.length.to_s + " package(s) needs updating."
end

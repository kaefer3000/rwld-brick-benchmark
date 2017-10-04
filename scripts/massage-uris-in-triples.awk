{ command="echo \""$0"\" | sed -E 's/\\<\\S*IBM_B3#(\\S*)>/\\1>/g' " ; command | getline ; print > $(NF-1) }

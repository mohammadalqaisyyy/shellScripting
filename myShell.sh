#!/bin/bash

search_dir=$1

advance_search()
{
        find_command="find $search_dir"
        file_extension=$1
        min_size=$2
        max_size=$3
        permissions=$4
        timestamp=$5

        if [[ -n $min_size ]]; then
                find_command+=" -size +${min_size}c"
        fi

        if [[ -n $max_size ]]; then
                find_command+=" -size -${max_size}c"
        fi

        if [[ -n $permissions ]]; then
                find_command+=" -perm $permissions"
        fi

        if [[ -n $timestamp ]]; then
                find_command+=" -mmin -$timestamp"
        fi
        
        if [[ -n $file_extension ]]; then
                find_command+=" -name '*.$file_extension'"
        fi

        eval $find_command
}

report()
{
        report_details=""
        on_file=$1
        
        while read -r -d '' file; do
                if [ -f $file ]
                then
                        filename=$(stat -c "%n" "$file" | rev | cut -d'/' -f1 | rev)
                        user=$(stat -c "%U" "$file")
                        permissions=$(stat -c "%A" "$file")
                        last_modified=$(stat -c "%Y" "$file")
                        size=$(stat -c "%s" "$file")
                        
                        report_details+="$filename\t\t$user \t $permissions \t $last_modified \t $size"$'\n'
                fi
        done < <(find "$search_dir" -type f -print0)
        
        if [[ "$on_file" == "-s" ]] || [[ "$on_file" == "--save" ]]; then
                > file_analysis.txt
                printf "$report_details" >> file_analysis.txt
                echo "done"
        elif test -z ${on_file}; then
                printf "$report_details"
        else 
                echo "rp: cannot access '$on_file': not option, use help command";
        fi
}

owner_groups()
{
        unset groups
        declare -A groups
        declare -A group_sizes
        sorted=$1

        while read -r -d '' file; do
            owner=$(stat -c "%U" "$file")
            filename=$(basename "$file")
            size=$(stat -c "%s" "$file")
            groups[$owner]+="$filename"$'\t'
            ((group_sizes[$owner] += size))
        done < <(find "$search_dir" -type f -print0)

        if [[ "$sorted" == "-s" ]] || [[ "$sorted" == "--sort" ]]; then
                IFS=$'\n' read -rd '' -a sorted_owners <<< "$(for owner in "${!groups[@]}"; do
                    echo "${group_sizes[$owner]}:$owner"  # Append owner at end
                done | sort -rn | cut -d':' -f2)"
                for sorted_owner in "${sorted_owners[@]}"; do
                    owner="${sorted_owner##*$'\t'}"
                    echo "Owner: $owner"
                    echo "Size: ${group_sizes[$owner]}"
                    echo "${groups[$owner]}"
                    echo
                done
        elif test -z ${sorted}; then
                for owner in "${!groups[@]}"; do
                        echo "Owner: $owner"
                        echo "${groups[$owner]}"
                        echo
                done
        else
                echo "gp: cannot access '$sorted': not option, use help command";
        fi
}

help()
{
        echo "Usage: ./myShell.sh [OPTIONS]"
        echo
        echo "Options:"
        echo "  ls                       Lists all files in the specified directory and its subdirectories."
        echo "  ls [File extension]      Lists files with a specific extension (e.g., .txt) in the specified directory and its subdirectories."
        echo
        echo "  as                       Filters files based on file extension, size, permissions, or last modified timestamp."
        echo
        echo "  rp                       Generates a comprehensive report of file details on the terminal."
        echo "                           -s, --save        Saves the report in 'file_analysis.txt'."
        echo
        echo "  gp                       Groups files by owner, providing an overview of ownership distribution."
        echo "                           -s, --sort        Sorts file groups by the total size occupied by each owner."
        echo "  summary                  Provides a summary of the directory contents and ownership details."
}

describe()
{
        file_count=0
        total_size=0
        group_count=0
        owner_count=0
        
        unset owners
        unset groups
        
        files=$(find "$search_dir" -type f)
  
        for file in $files; do
                ((file_count++))

                size=$(stat -c "%s" "$file")
                ((total_size+=size))

                group=$(stat -c "%G" "$file")
                if ! grep -q "$group" <<< "$groups"; then
                        ((group_count++))
                        groups+=("$group")
                fi
            
                owner=$(stat -c "%U" "$file")
                if ! grep -q "$owner" <<< "$owners"; then
                        ((owner_count++))
                        owners+=("$owner")
                fi
    
        done
        
        echo
        echo "File count: $file_count"
        echo "Total size: $total_size bytes"
        echo "Group count: $group_count"
        echo "Owner count: $owner_count"
        echo
}

while true; do
        read -p "myShell: " command command2
        if test -z "${command}"; then
                :
                
        elif [[ "$command" == "ls" ]]; then
                advance_search $command2
        
        elif [[ "$command" == "as" ]]; then
                read -p "Enter file extension (e.g., txt, c): " file_extension
                read -p "Enter minimum file size (in bytes): " min_size
                read -p "Enter maximum file size (in bytes): " max_size
                read -p "Enter file permissions (e.g., 775): " permissions
                read -p "Enter last modified timestamp (in minutes): " timestamp
                
                advance_search $file_extension $min_size $max_size $permissions $timestamp
                
        
        elif [[ "$command" == "rp" ]] || [[ "$command" == "report" ]]; then
                report $command2
        
        elif [[ "$command" == "gp" ]]; then
                owner_groups $command2
        
        elif [[ "$command" == "clear" ]]; then
                clear
        
        elif [[ "$command" == "help" ]]; then
                help
                
        elif [[ "$command" == "summary" ]] || [[ "$command" == "summ" ]]; then
                describe
        
        else
                echo "$command: command not found, use help command"
        fi
done



#!/bin/bash

set -euo pipefail

# Define the root directory here
dir="/data_heath/archive/miseq/"

# Initialize a counter
count=0

# Maximum number of directories to process
max=40

cd $dir

# Go through each sub-directory
for d in ./*/ ; do
    echo $d

    # Break if maximum count reached
    if [ $count -eq $max ]; then
        break
    fi

    # Check if it's a directory and if the tar file does not exist
    if [ -d "$d" ] && [ ! -f "${d%/}.tar" ]; then
        # Archive the directory
        tar -cf "${d%/}.tar" "$d"

        # Check if tar command was successful
        if [ $? -eq 0 ]; then
            echo "Archived $d"
            # Remove the original directory
            rm -r "$d"
            # Check if rm command was successful
            if [ $? -eq 0 ]; then
                echo "Removed $d"
            else
                echo "Failed to remove $d"
            fi
        else
            echo "Failed to archive $d"
        fi
        # Increment the counter
        count=$((count+1))
        # Sleep for a minute
        sleep 500
    fi
done




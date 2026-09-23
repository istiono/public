adb_sync_check() {
    # Usage check
    if [ -z "$1" ]; then
        echo "❌ Error: Missing source file."
        echo "Usage: adb_sync_check <source_file> [target_folder]"
        echo "Example (Linux to Android): adb_sync_check /path/to/linux.mp4 adb:/sdcard/Download"
        echo "Example (Android to Linux): adb_sync_check adb:/sdcard/video.mp4 /path/to/linux_dir"
        return 1
    fi

    local src="$1"
    local dest="${2:-$(pwd)}" # Default to current directory if not provided

    local src_is_android=false
    local dest_is_android=false

    # Detect if source or destination is Android (prefixed with adb:)
    if [[ "$src" =~ ^adb: ]]; then src_is_android=true; src="${src#adb:}"; fi
    if [[ "$dest" =~ ^adb: ]]; then dest_is_android=true; dest="${dest#adb:}"; fi

    # Extract filename to build final target path
    local filename=$(basename "$src")
    local dest_file="${dest%/}/$filename"

    echo "----------------------------------------"
    echo "Source:      $( [ "$src_is_android" = true ] && echo "Android:" || echo "Linux:" ) $src"
    echo "Destination: $( [ "$dest_is_android" = true ] && echo "Android:" || echo "Linux:" ) $dest_file"
    echo "----------------------------------------"

    # Step 1: Prompt to Copy
    read -p "❓ Do you want to copy the file first? (y/N): " do_copy
    if [[ "$do_copy" =~ ^[yY]([eE][sS])?$ ]]; then
        echo "🚀 Copying file..."
        if [ "$src_is_android" = true ] && [ "$dest_is_android" = false ]; then
            adb pull "$src" "$dest_file"
        elif [ "$src_is_android" = false ] && [ "$dest_is_android" = true ]; then
            adb push "$src" "$dest_file"
        elif [ "$src_is_android" = false ] && [ "$dest_is_android" = false ]; then
            cp "$src" "$dest_file"
        else
            echo "❌ Error: Direct Android-to-Android copy via ADB syntax not supported."
            return 1
        fi
    else
        echo "⏩ Skipping copy step. Proceeding to hash check..."
    fi

    # Step 2: Calculate Hashes
    echo "🧮 Calculating hashes..."
    local src_hash=""
    local dest_hash=""

    # Calculate Source Hash
    if [ "$src_is_android" = true ]; then
        src_hash=$(adb shell sha256sum "\"$src\"" 2>/dev/null | awk '{print $1}' | tr -d '\r')
    else
        src_hash=$(sha256sum "$src" 2>/dev/null | awk '{print $1}')
    fi

    # Calculate Destination Hash
    if [ "$dest_is_android" = true ]; then
        dest_hash=$(adb shell sha256sum "\"$dest_file\"" 2>/dev/null | awk '{print $1}' | tr -d '\r')
    else
        dest_hash=$(sha256sum "$dest_file" 2>/dev/null | awk '{print $1}')
    fi

    # Verify hashes were actually generated
    if [ -z "$src_hash" ] || [ -z "$dest_hash" ] || [[ "$src_hash" == *"No"* ]] || [[ "$dest_hash" == *"No"* ]]; then
        echo "❌ Error: Could not compute hashes. Ensure files exist on both sides."
        return 1
    fi

    echo "Source Hash: $src_hash"
    echo "Target Hash: $dest_hash"

    # Step 3: Compare and Optional Delete
    if [ "$src_hash" == "$dest_hash" ]; then
        echo "✅ SUCCESS: Hashes match perfectly!"
        
        read -p "🗑️ Do you want to delete the SOURCE file now? (y/N): " do_delete
        if [[ "$do_delete" =~ ^[yY]([eE][sS])?$ ]]; then
            if [ "$src_is_android" = true ]; then
                adb shell rm "\"$src\""
                echo "🧹 Deleted remote Android file: $src"
            else
                rm "$src"
                echo "🧹 Deleted local Linux file: $src"
            fi
        else
            echo "💾 Source file kept intact."
        fi
    else
        echo "❌ ERROR: Hashes DO NOT match! Deletion aborted to prevent data loss."
        return 1
    fi
}
adb_sha256() {
    if [ -z "$1" ]; then
        echo "Error: Missing remote file path."
        echo "Usage: adb_sha256 /path/to/remote/file.ext"
        return 1
    fi

    local REMOTE_FILE="$1"
    local SHA_FILE="${REMOTE_FILE}.sha256"

    echo "Calculating SHA-256 for: $REMOTE_FILE"
    
    # Run the hash on Android and write the output side-by-side
    adb shell "sha256sum '$REMOTE_FILE' > '$SHA_FILE'"

    if [ $? -eq 0 ]; then
        echo "Successfully created side-car file: $SHA_FILE"
        # Print the contents to verify
        echo -n "Hash value: "
        adb shell "cat '$SHA_FILE'"
    else
        echo "Failed to create hash. Check file path or permissions."
    fi
}

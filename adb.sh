adb_sync_check() {
    local OPTIND opt TARGET_USER=""
    
    # Parse -u option if present
    while getopts "u:" opt; do
        case ${opt} in
            u) TARGET_USER=$OPTARG ;;
            *) echo "Usage: adb_sync_check [-u user] <source_file> [target_folder]"; return 1 ;;
        esac
    done
    shift $((OPTIND -1))

    # Usage check
    if [ -z "$1" ]; then
        echo "❌ Error: Missing source file."
        echo "Usage: adb_sync_check [-u user] <source_file> [target_folder]"
        return 1
    fi

    local src="$1"
    local dest="${2:-$(pwd)}"

    local src_is_android=false
    local dest_is_android=false
    if [[ "$src" =~ ^adb: ]]; then src_is_android=true; src="${src#adb:}"; fi
    if [[ "$dest" =~ ^adb: ]]; then dest_is_android=true; dest="${dest#adb:}"; fi

    # --- NEW: Interactive prompt if user wasn't passed via flag ---
    if [ "$src_is_android" = true ] || [ "$dest_is_android" = true ]; then
        if [ -z "$TARGET_USER" ]; then
            read -p "👤 Enter Android User (e.g. root, 0, 10, or leave blank for default): " TARGET_USER
        fi
    fi

    # Helper function to wrap ADB shell commands
    adb_shell_run() {
        if [ -n "$TARGET_USER" ]; then
            adb shell "su $TARGET_USER -c \"$1\""
        else
            adb shell "$1"
        fi
    }

    local filename=$(basename "$src")
    local dest_file="${dest%/}/$filename"

    echo "----------------------------------------"
    echo "Source:      $( [ "$src_is_android" = true ] && echo "Android (User: ${TARGET_USER:-default}):" || echo "Linux:" ) $src"
    echo "Destination: $( [ "$dest_is_android" = true ] && echo "Android (User: ${TARGET_USER:-default}):" || echo "Linux:" ) $dest_file"
    echo "----------------------------------------"

    # Step 1: Prompt to Copy
    read -p "❓ Do you want to copy the file first? (y/N): " do_copy
    if [[ "$do_copy" =~ ^[yY]([eE][sS])?$ ]]; then
        echo "🚀 Copying file..."
        if [ "$src_is_android" = true ] && [ "$dest_is_android" = false ]; then
            if [ -n "$TARGET_USER" ]; then
                adb_shell_run "cp \"$src\" /data/local/tmp/sync_tmp && chmod 666 /data/local/tmp/sync_tmp" 2>/dev/null
                adb pull "/data/local/tmp/sync_tmp" "$dest_file"
                adb_shell_run "rm /data/local/tmp/sync_tmp" 2>/dev/null
            else
                adb pull "$src" "$dest_file"
            fi
        elif [ "$src_is_android" = false ] && [ "$dest_is_android" = true ]; then
            if [ -n "$TARGET_USER" ]; then
                adb push "$src" "/data/local/tmp/sync_tmp"
                adb_shell_run "mv /data/local/tmp/sync_tmp \"$dest_file\" && chown $TARGET_USER \"$dest_file\""
            else
                adb push "$src" "$dest_file"
            fi
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

    if [ "$src_is_android" = true ]; then
        src_hash=$(adb_shell_run "sha256sum \"$src\"" 2>/dev/null | awk '{print $1}' | tr -d '\r')
    else
        src_hash=$(sha256sum "$src" 2>/dev/null | awk '{print $1}')
    fi

    if [ "$dest_is_android" = true ]; then
        dest_hash=$(adb_shell_run "sha256sum \"$dest_file\"" 2>/dev/null | awk '{print $1}' | tr -d '\r')
    else
        dest_hash=$(sha256sum "$dest_file" 2>/dev/null | awk '{print $1}')
    fi

    if [ -z "$src_hash" ] || [ -z "$dest_hash" ] || [[ "$src_hash" == *"No"* ]] || [[ "$dest_hash" == *"No"* ]]; then
        echo "❌ Error: Could not compute hashes. Ensure files exist on both sides and permissions are correct."
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
                adb_shell_run "rm \"$src\""
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
    local OPTIND opt TARGET_USER=""
    
    while getopts "u:" opt; do
        case ${opt} in
            u) TARGET_USER=$OPTARG ;;
            *) echo "Usage: adb_sha256 [-u user] /path/to/remote/file.ext"; return 1 ;;
        esac
    done
    shift $((OPTIND -1))

    if [ -z "$1" ]; then
        echo "Error: Missing remote file path."
        return 1
    fi

    # --- NEW: Interactive prompt if user wasn't passed via flag ---
    if [ -z "$TARGET_USER" ]; then
        read -p "👤 Enter Android User (e.g. root, 0, 10, or leave blank for default): " TARGET_USER
    fi

    local REMOTE_FILE="$1"
    local SHA_FILE="${REMOTE_FILE}.sha256"

    echo "Calculating SHA-256 for: $REMOTE_FILE $([ -n "$TARGET_USER" ] && echo "(as user: $TARGET_USER)")"
    
    if [ -n "$TARGET_USER" ]; then
        adb shell "su $TARGET_USER -c \"sha256sum '$REMOTE_FILE' > '$SHA_FILE'\""
    else
        adb shell "sha256sum '$REMOTE_FILE' > '$SHA_FILE'"
    fi

    if [ $? -eq 0 ]; then
        echo "Successfully created side-car file: $SHA_FILE"
        echo -n "Hash value: "
        if [ -n "$TARGET_USER" ]; then
            adb shell "su $TARGET_USER -c \"cat '$SHA_FILE'\""
        else
            adb shell "cat '$SHA_FILE'"
        fi
    else
        echo "Failed to create hash. Check file path or permissions."
    fi
}

 compgen -c | egrep clean_firefox_dir
clean_firefox_dir() {
    # 1. Ensure an argument is provided
    if [ -z "$1" ]; then
        echo "Error: Please provide a folder name inside ~/.mozilla/firefox/."
        return 1
    fi

    # 2. Construct and resolve the absolute target path
    local target_dir="$HOME/.mozilla/firefox/$1"

    # 3. Safety checks: Ensure the directory exists and is actually inside the Firefox profile
    if [ ! -d "$target_dir" ]; then
        echo "Error: Directory '$target_dir' does not exist."
        return 1
    fi

    # Resolve paths to prevent directory traversal tricks (e.g., passing '../../')
    local real_target=$(readlink -f "$target_dir")
    local real_base=$(readlink -f "$HOME/.mozilla/firefox")

    if [[ "$real_target" != "$real_base"* ]] || [ "$real_target" == "$real_base" ]; then
        echo "Error: Operation restricted to subdirectories inside ~/.mozilla/firefox/ only."
        return 1
    fi

    echo "Processing directory: $real_target"
    echo "=================================================="

    # 4. Find and process all items recursively
    # Using a loop safely handles spaces and special characters in filenames
    find "$real_target" -mindepth 1 | while read -r item; do
        
        # Check ownership (Current user UID vs file owner UID)
        local owner_uid=$(stat -c '%u' "$item" 2>/dev/null)
        if [ "$owner_uid" != "$UID" ]; then
            echo "[⚠️ NOT OWNED BY YOU] Skipping: $item"
            continue
        fi

        # Check if it is a regular file
        if [ -f "$item" ] && [ ! -L "$item" ]; then
            local dir_name=$(dirname "$item")
            local rename_path="$dir_name/0"

            # Rename the file to '0'
            if mv "$item" "$rename_path" 2>/dev/null; then
                # Truncate the renamed file to 0 bytes
                > "$rename_path"
                # Delete the file
                rm "$rename_path"
                echo "[✓ TRUNCATED & DELETED] $item"
            else
                echo "[❌ ERROR] Could not rename/process: $item"
            fi
        else
            # Inform about non-regular files (directories, symlinks, sockets, etc.)
            if [ -d "$item" ]; then
                echo "[ℹ️ DIRECTORY] Skipping: $item"
            elif [ -L "$item" ]; then
                echo "[ℹ️ SYMLINK] Skipping: $item"
            else
                echo "[ℹ️ NON-REGULAR FILE] Skipping: $item"
            fi
        fi
    done
}
#Copy the code into your terminal or append it to your ~/.bashrc file.

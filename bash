 compgen -c | egrep clean_firefox_dir
clean_firefox_dir() {
    # 1. Ensure an argument is provided
    if [ -z "$1" ]; then
        echo "Error: Please provide a folder name or full path inside ~/.mozilla/firefox/."
        return 1
    fi

    # 2. Smart Path Resolution: Clean up the input argument
    local input_path="$1"
    
    # Replace literal '~' character string with the actual $HOME environment variable path
    input_path="${input_path/#\~/$HOME}"
    
    # Extract just the folder name if they passed the whole path prefix
    local target_folder="${input_path#$HOME/.mozilla/firefox/}"

    # Construct the final absolute target path
    local target_dir="$HOME/.mozilla/firefox/$target_folder"

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

    # Report files NOT owned by you
    find "$real_target" -mindepth 1 ! -user "$UID" -exec echo "[⚠️ NOT OWNED BY YOU] Skipping:" {} \;

    # Report non-regular files (directories, symlinks, etc.) owned by you
    find "$real_target" -mindepth 1 -user "$UID" ! -type f -exec sh -c '
        for item; do
            [ -d "$item" ] && echo "[ℹ️ DIRECTORY] Skipping: $item" && continue
            [ -L "$item" ] && echo "[ℹ️ SYMLINK] Skipping: $item" && continue
            echo "[ℹ️ NON-REGULAR FILE] Skipping: $item"
        done
    ' sh {} +

    echo "--------------------------------------------------"
    echo "Truncating and deleting regular files..."

    # 4. Find and process all regular files using chained -execdir commands
    find "$real_target" -mindepth 1 -type f -user "$UID" \
        -execdir mv -- {} 0 \; \
        -execdir truncate -s 0 0 \; \
        -execdir rm -- 0 \;

    echo "Operation completed."
}
#Copy the code into your terminal or append it to your ~/.bashrc file.

#!/usr/bin/env python3
import os
import sys

m3u_file = "/media/sari/New Volume1/1/e/3.m3u"
m3u_dir = os.path.dirname(os.path.abspath(m3u_file))

entries = []
removed = 0

with open(m3u_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

i = 0
while i < len(lines):
    line = lines[i].strip()
    
    if line.startswith('#EXTINF'):
        if i + 1 < len(lines):
            media_path = lines[i + 1].strip()
            
            # Resolve path
            if os.path.isabs(media_path):
                full_path = media_path
            else:
                full_path = os.path.join(m3u_dir, media_path)
            
            # Check if file exists
            if os.path.isfile(full_path):
                entries.append(lines[i])
                entries.append(lines[i + 1])
            else:
                print(f"Removed: {media_path}")
                removed += 1
            i += 2
        else:
            i += 1
    else:
        if line:
            entries.append(lines[i])
        i += 1

# Write back
with open(m3u_file, 'w', encoding='utf-8') as f:
    f.writelines(entries)

print(f"Done! Removed {removed} entries.")


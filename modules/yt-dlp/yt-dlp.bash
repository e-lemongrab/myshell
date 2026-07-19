#!/bin/bash
echo "Playlist Name:"
read playlist_name
echo "Playlist URL"
read playlist_url
mkdir ~/Downloads/"$playlist_name"
cd ~/Downloads/"$playlist_name" || exit 1
/usr/bin/yt-dlp -x -o "%(playlist_index)s-%(title)s.%(ext)s" --format mp4 $playlist_url

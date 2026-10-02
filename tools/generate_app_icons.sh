#!/usr/bin/env bash
# Generates iOS and Android app icon sets from a 1024x1024 master artwork image.
#
# Usage:
#   tools/generate_app_icons.sh [path/to/master_1024.png]

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
master="${1:-$repo_root/assets/images/courier/run_1.png}"

ios_iconset="$repo_root/ios/Runner/Assets.xcassets/AppIcon.appiconset"
android_res="$repo_root/android/app/src/main/res"

if [ ! -f "$master" ]; then
    echo "Error: Master icon not found at $master" >&2
    exit 1
fi

echo "Generating icons from $master..."

# iOS icon resolutions (downsampled via sips on macOS or convert on Linux)
declare -A ios_sizes=(
    ["Icon-App-20x20@1x.png"]="20"
    ["Icon-App-20x20@2x.png"]="40"
    ["Icon-App-20x20@3x.png"]="60"
    ["Icon-App-29x29@1x.png"]="29"
    ["Icon-App-29x29@2x.png"]="58"
    ["Icon-App-29x29@3x.png"]="87"
    ["Icon-App-40x40@1x.png"]="40"
    ["Icon-App-40x40@2x.png"]="80"
    ["Icon-App-40x40@3x.png"]="120"
    ["Icon-App-60x60@2x.png"]="120"
    ["Icon-App-60x60@3x.png"]="180"
    ["Icon-App-76x76@1x.png"]="76"
    ["Icon-App-76x76@2x.png"]="152"
    ["Icon-App-83.5x83.5@2x.png"]="167"
    ["Icon-App-1024x1024@1x.png"]="1024"
)

# Android mipmap densities
declare -A android_sizes=(
    ["mipmap-mdpi"]="48"
    ["mipmap-hdpi"]="72"
    ["mipmap-xhdpi"]="96"
    ["mipmap-xxhdpi"]="144"
    ["mipmap-xxxhdpi"]="192"
)

if command -v sips >/dev/null 2>&1; then
    # macOS sips
    for file in "${!ios_sizes[@]}"; do
        size="${ios_sizes[$file]}"
        sips -z "$size" "$size" "$master" --out "$ios_iconset/$file" >/dev/null
    done

    for dir in "${!android_sizes[@]}"; do
        size="${android_sizes[$dir]}"
        mkdir -p "$android_res/$dir"
        sips -z "$size" "$size" "$master" --out "$android_res/$dir/ic_launcher.png" >/dev/null
    done
elif command -v convert >/dev/null 2>&1; then
    # ImageMagick
    for file in "${!ios_sizes[@]}"; do
        size="${ios_sizes[$file]}"
        convert "$master" -resize "${size}x${size}" "$ios_iconset/$file"
    done

    for dir in "${!android_sizes[@]}"; do
        size="${android_sizes[$dir]}"
        mkdir -p "$android_res/$dir"
        convert "$master" -resize "${size}x${size}" "$android_res/$dir/ic_launcher.png"
    done
fi

echo "App icon generation completed successfully."

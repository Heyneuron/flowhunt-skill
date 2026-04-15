#!/usr/bin/env bash
# Print the recommended ActivityWatch install command for the current OS.
# Used by setup.md when aw-check.sh returns NOT_INSTALLED.

os="$(uname -s)"

case "$os" in
    Darwin)
        if command -v brew > /dev/null 2>&1; then
            echo "brew install --cask activitywatch"
        else
            echo "# Homebrew not found. Install Homebrew first:"
            echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            echo "# Then:"
            echo "brew install --cask activitywatch"
        fi
        ;;
    Linux)
        echo "# No apt/yum package exists. Download the latest tarball:"
        echo "# https://activitywatch.net/downloads/"
        echo "# Extract, then run ./aw-qt"
        ;;
    MINGW*|CYGWIN*|MSYS*)
        if command -v winget > /dev/null 2>&1; then
            echo "winget install ActivityWatch.ActivityWatch"
        else
            echo "# Download the Windows installer:"
            echo "# https://activitywatch.net/downloads/"
        fi
        ;;
    *)
        echo "# Unknown OS ($os). Download manually from:"
        echo "# https://activitywatch.net/downloads/"
        ;;
esac

#!/usr/bin/env bash

# Check for Carthage
printf "Checking for Carthage: "
carthage version >/dev/null 2>&1 || { printf >&2 "nope!\nCarthage must be installed. Try running:\n\tbrew install carthage\n"; exit 1; }
printf "found!\n"

# Check for swiftlint
printf "Checking for swiftlint: "
swiftlint version >/dev/null 2>&1 || { printf >&2 "nope!\nswiftlint must be installed. Try running:\n\tbrew install swiftlint\n"; exit 1; }
printf "found!\n"

# Check for installed ruby version
printf "Checking for rbenv: "
rbenv version >/dev/null 2>&1 || { printf >&2 "nope!\nrbenv must be installed. Try running:\n\tbrew install rbenv\n"; exit 1; }
printf "found!\n"
printf "Ensuring correct ruby version is installed:\n"
rbenv install -s
printf "Correct ruby version installed!\n"

# Install CocoaPods via bundler
printf "Checking for bundler: "
bundle version >/dev/null 2>&1 || { printf >&2 "nope!\nbundler must be installed. Try running:\n\tgem install bundler\n"; exit 1; }
printf "\nInstalling CocoaPods via bundler:\n"
bundle install
bundle exec pod --version >/dev/null 2>&1 || { echo >&2 "CocoaPods failed to install! You might want to open an issue for this: https://github.com/ianyh/Amethyst/issues/new"; exit 1; }

# Install pods
printf "Installing Pods:\n"
bundle exec pod install

# Build Carthage dependencies
printf "Building Carthage frameworks:\n"
carthage bootstrap --platform mac --cache-builds

printf "\n\nDone! Now you can open Amethyst.xcworkspace and build\n"

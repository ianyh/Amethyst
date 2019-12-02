#!/usr/bin/env bash

# Check Xcode version (TODO: semver)
OUR_XCODE=11.0
printf "Checking if xcode-select points to the Xcode version we use ($OUR_XCODE): "
if [ `xcodebuild -version | grep Xcode | awk '{print $2}'` = $OUR_XCODE ] ; then
    printf "found!\n"
else
    printf "nope!\n"
    printf "WARNING: Xcode $OUR_XCODE is used to develop this project.\n"
fi

# Check for swiftlint
printf "Checking for swiftlint: "
swiftlint version >/dev/null 2>&1 || { printf >&2 "nope!\nswiftlint must be installed. Try running:\n\tbrew install swiftlint\n"; exit 1; }
printf "found!\n"

# Check for installed ruby version
printf "Checking for rbenv: "
if rbenv version >/dev/null 2>&1 ; then
    printf "found!\n"
    printf "Ensuring correct ruby version is installed:\n"
    rbenv install -s
    printf "Correct ruby version installed!\n"

else
    printf "nope!\n"
    ACTUAL=`ruby -v | awk '{print $2}' | awk -Fp '{print $1}' | tr -d '\n'`
    EXPECTED=`cat .ruby-version | tr -d '\n'`
    if [ $ACTUAL = $EXPECTED ] ; then
	printf "Correct ruby version is already installed, without rbenv\n"
    else
	printf "WARNING: You have ruby $ACTUAL, we want ruby $EXPECTED, and rbenv is not installed.\n"
	printf "If you encounter setup problems, Try running:\n\tbrew install rbenv\n"
    fi
fi

# Install CocoaPods via bundler
printf "Checking for bundler: "
bundle version >/dev/null 2>&1 || { printf >&2 "nope!\nbundler must be installed. Try running:\n\tgem install bundler\n"; exit 1; }
printf "\nInstalling CocoaPods via bundler:\n"
bundle install
bundle exec pod --version >/dev/null 2>&1 || { echo >&2 "CocoaPods failed to install! You might want to open an issue for this: https://github.com/ianyh/Amethyst/issues/new"; exit 1; }

# Install pods
printf "Installing Pods:\n"
bundle exec pod install

printf "\n\nDone! Now you can open Amethyst.xcworkspace and build\n"

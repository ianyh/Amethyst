#!/usr/bin/env bash

# Check Xcode version (TODO: semver)
OUR_XCODE=11.6
OUR_RUBY=`cat .ruby-version | tr -d '\n'`
printf "Checking if xcode-select points to the Xcode version we use ($OUR_XCODE): "
if [ `xcodebuild -version | grep Xcode | awk '{print $2}'` = $OUR_XCODE ] ; then
    printf "found!\n"
else
    printf "nope!\n"
    printf "WARNING: Xcode $OUR_XCODE is used to develop this project.\n"
fi

# Check for installed ruby version
printf "Checking for rbenv: "
which rbenv >/dev/null 2>&1 
if [ $? -eq 0 ]; then
    printf "found!\n"
    printf "Ensuring correct ruby version ($OUR_RUBY) is installed:\n"
    rbenv install -s $OUR_RUBY
    eval "$(rbenv init -)"
    ACTUAL_RUBY=`ruby -v | awk '{print $2}' | awk -Fp '{print $1}' | tr -d '\n'`
    printf "Correct ruby version installed: $ACTUAL_RUBY\n"
    gem install bundler
    rbenv rehash
else
    printf "nope!\n"
    ACTUAL=`ruby -v | awk '{print $2}' | awk -Fp '{print $1}' | tr -d '\n'`
    if [ $ACTUAL = $OUR_RUBY ] ; then
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

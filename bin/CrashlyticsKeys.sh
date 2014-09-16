#!/usr/bin/env bash

if [ -f crashlytics_api_key ]; then
    export CRASHLYTICS_API_KEY="$(cat Amethyst/crashlytics_api_key)"
fi

if [ -f crashlytics_app_key ]; then
    export CRASHLYTICS_APP_KEY="$(cat Amethyst/crashlytics_app_key)"
fi

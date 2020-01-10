#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source tool/bots/util.sh

echo "==== Performing standard bot setup ===="
start=`date +%s`

if [ -z "$USE_LOCAL_DEPENDENCIES" ]; then
    echo "Using dependencies from Pub"
else
    echo "Updating pubspecs to use local dependencies"
    perl -pi -e 's/#OVERRIDE_FOR_TESTS//' packages/devtools/pubspec.yaml
    perl -pi -e 's/#OVERRIDE_FOR_TESTS//' packages/devtools_app/pubspec.yaml
fi

# Some integration tests assume the devtools package is up to date and located
# adjacent to the devtools_app package.
pushd packages/devtools
    # We want to make sure that devtools is retrievable with regular pub.
    pub get
    # Only package:devtools and package:devtools_server should be built with
    # the pub tool. All other devtools packages and their tests now run on
    # the flutter tool, so all other invocations of pub in this script should
    # call 'flutter pub' instead of just 'pub'.
popd

# Add globally activated packages to the path.
if [[ $TRAVIS_OS_NAME == "windows" ]]; then
    export PATH=$PATH:$APPDATA/Roaming/Pub/Cache/bin
else
    export PATH=$PATH:~/.pub-cache/bin
fi

if [[ $TRAVIS_OS_NAME == "windows" ]]; then
    echo Installing Google Chrome Stable...
    # Install Chrome via Chocolatey while `addons: chrome` doesn't seem to work on Windows yet
    # https://travis-ci.community/t/installing-google-chrome-stable-but-i-cant-find-it-anywhere/2118
    choco install googlechrome --acceptlicense --yes --no-progress --ignore-checksums
fi

# Get Flutter.
if [ "$TRAVIS_DART_VERSION" = "stable" ]; then
    echo "Cloning stable Flutter branch"
    git clone https://github.com/flutter/flutter.git --branch stable ./flutter

    # Set the suffix so we use stable goldens.
    export DEVTOOLS_GOLDENS_SUFFIX="_stable"
else
    echo "Cloning master Flutter branch"
    git clone https://github.com/flutter/flutter.git ./flutter

    # Set the suffix so we use the master goldens
    export DEVTOOLS_GOLDENS_SUFFIX=""
fi
export PATH=`pwd`/flutter/bin:`pwd`/flutter/bin/cache/dart-sdk/bin:$PATH
flutter config --no-analytics
flutter doctor
# We should be using dart from ../flutter/bin/cache/dart-sdk/bin/dart.
echo "which dart: " `which dart`

pushd packages/devtools_app
echo `pwd`

# Print out the versions and ensure we can call Dart, Pub, and Flutter.
dart --version
flutter pub --version
# Put the Flutter version into a variable.
# First awk extracts "Flutter x.y.z-pre.a":
#   -F '•'         uses the bullet as field separator
#   NR==1          says only take the first record (line)
#   { print $1}    prints just the first field
# Second awk splits on space (default) and takes the second field (the version)
export FLUTTER_VERSION=$(flutter --version | awk -F '•' 'NR==1{print $1}' | awk '{print $2}')
echo "Flutter version is '$FLUTTER_VERSION'"
popd

end=`date +%s`
echo "==== Standard bot setup completed in $((end-start)) second(s) ===="
#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source tool/bots/util.sh

echo "==== Running main bot ===="
start=`date +%s`
pushd packages/devtools_app

# Provision our packages.
flutter pub get
flutter pub global activate webdev

# Verify that dartfmt has been run.
echo "Checking dartfmt..."

if [[ $(dartfmt -n --set-exit-if-changed lib/ test/ web/) ]]; then
    echo "Failed dartfmt check: run dartfmt -w lib/ test/ web/"
    dartfmt -n --set-exit-if-changed lib/ test/ web/
    exit 1
fi

# Make sure the app versions are in sync.
dart tool/version_check.dart

# Analyze the source.
flutter pub global activate tuneup && flutter pub global run tuneup check

# Ensure we can build the app.
flutter pub run build_runner build -o web:build --release

popd
end=`date +%s`
echo "==== Main tests completed in $((end-start)) second(s) ===="

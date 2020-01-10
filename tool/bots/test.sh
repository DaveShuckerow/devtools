#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source tool/bots/util.sh


if [ "$WEBDEV_RELEASE" = "true" ]; then
    echo "==== Running test_dart2js tests ===="
else
    echo "==== Running test_ddc tests ===="
fi

start=`date +%s`
pushd packages/devtools_app

flutter pub get

# TODO(https://github.com/flutter/flutter/issues/43538): Remove workaround.
flutter config --enable-web
flutter build web

# Run every test except for integration_tests.
# The flutter tool doesn't support excluding a specific set of targets,
# so we explicitly provide them.
# If a specific platform is given, only run the corresponding tests.
# Else, run tests on all platforms.
# If environment variable WEBDEV_RELEASE is true, run dart2js tests.
# Else, run ddc tests.
if [ "$PLATFORM" = "vm" ] || [ "$PLATFORM" = "" ]; then
    flutter test test/*.dart test/{core,fixtures,flutter,support,ui}/
elif [ "$PLATFORM" = "chrome" ] || [ "$PLATFORM" = "" ]; then
    flutter test --platform chrome test/*.dart test/{core,fixtures,flutter,support,ui}/
fi
echo $WEBDEV_RELEASE

popd
end=`date +%s`
echo "==== Test_dart2js tests completed in $((end-start)) second(s) ===="
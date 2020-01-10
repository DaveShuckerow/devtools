#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source tool/bots/util.sh

if [ "$WEBDEV_RELEASE" = "true" ]; then
    echo "==== Running integration_dart2js tests ===="
else
    echo "==== Running integration_ddc tests ===="
fi
start=`date +%s`
pushd packages/devtools_app

# Provision our packages.
flutter pub get
flutter pub global activate webdev

# If environment variable WEBDEV_RELEASE is true, run dart2js tests.
# Else, run ddc tests.
# We need to run integration tests with -j1 to run with no concurrency.
flutter test -j1 test/integration_tests/

popd
end=`date +%s`
echo "==== Integration tests completed in $((end-start)) second(s) ===="
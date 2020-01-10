#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

source tool/bots/util.sh

echo "==== Running packages tests ===="
start=`date +%s`

flutter pub global activate tuneup

# Analyze packages/
(cd packages/devtools_app; flutter pub get)
(cd packages/devtools_server; flutter pub get)
(cd packages/devtools_testing; flutter pub get)
(cd packages/html_shim; flutter pub get)
(cd packages; flutter pub global run tuneup check)

# Analyze third_party/
(cd third_party/packages/ansi_up; flutter pub get)
(cd third_party/packages/mp_chart; flutter pub get)
(cd third_party/packages/plotly_js; flutter pub get)
(cd third_party/packages/split; flutter pub get)
(cd third_party/packages; flutter pub global run tuneup check)

# Analyze Dart code in tool/
(cd tool; flutter pub global run tuneup check)

end=`date +%s`
echo "==== Packages tests completed in $((end-start)) second(s) ===="
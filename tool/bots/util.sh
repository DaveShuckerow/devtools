#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# In GitBash on Windows, we have to call dartfmt.bat and flutter.bat so we alias
# them in this script to call the correct one based on the OS.
function pub {
	if [[ $TRAVIS_OS_NAME == "windows" ]]; then
        command pub.bat "$@"
    else
        command pub "$@"
    fi
}
function dartfmt {
	if [[ $TRAVIS_OS_NAME == "windows" ]]; then
        command dartfmt.bat "$@"
    else
        command dartfmt "$@"
    fi
}
function flutter {
	if [[ $TRAVIS_OS_NAME == "windows" ]]; then
        command flutter.bat "$@"
    else
        command flutter "$@"
    fi
}
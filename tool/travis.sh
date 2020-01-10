#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures, unless we're trying to run all bots.

if [ "$BOT" != "all" ]; then
  set -ex
fi

tool/bots/setup.sh

if [ "$BOT" = "main" ]; then

    tool/bots/main.sh

elif [ "$BOT" = "test_ddc" ]; then

    WEBDEV_RELEASE=false tool/bots/test.sh

elif [ "$BOT" = "test_dart2js" ]; then

    WEBDEV_RELEASE=true tool/bots/test.sh

elif [ "$BOT" = "integration_ddc" ]; then

    WEBDEV_RELEASE=false tool/bots/integration.sh

elif [ "$BOT" = "integration_dart2js" ]; then

    WEBDEV_RELEASE=true tool/bots/integration.sh

elif [ "$BOT" = "packages" ]; then

    tool/bots/packages.sh

elif [ "$BOT" = "all" ]; then

    tool/bots/main.sh
    WEBDEV_RELEASE=false tool/bots/test.sh
    WEBDEV_RELEASE=true tool/bots/test.sh
    WEBDEV_RELEASE=false tool/bots/integration.sh
    WEBDEV_RELEASE=true tool/bots/integration.sh
    tool/bots/packages.sh

else

    echo "unknown bot configuration"
    exit 1

fi

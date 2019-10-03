// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'src/config.dart';
import 'src/scaffold.dart';

void main() {
  // When running in a desktop embedder, Flutter throws an error because the
  // platform is not officially supported. This is not needed for web.
  final config = Config();
  runApp(
    MaterialApp(
      theme: ThemeData.light().copyWith(),
      routes: config.routes,
    ),
  );
}

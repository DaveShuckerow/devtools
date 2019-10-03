import 'dart:async';
import 'dart:io' as io;

import 'package:package_resolver/package_resolver.dart';
import 'package:test/test.dart';

/// Loads the widgets.json file that describes the widgets [Catalog].
Future<String> widgetsJson() async {
  final devtoolsPath = await resolvePackagePath('devtools_app');
  return await io.File('$devtoolsPath/web/widgets.json').readAsString();
}

Future<String> resolvePackagePath(String package) async {
  String path;
  try {
    path = await (PackageResolver.current).packagePath(package);
  } on UnsupportedError catch (e) {
    // PackageResolver makes calls to Isolate, which isn't accessible from a
    // flutter test run. Flutter test runs in the test directory of the app,
    // so the packages directory is the current directory's grandparent.
    String packagesPath;
    // TODO(https://github.com/flutter/flutter/issues/41932): When running an
    // individual test, the test command uses the app root directory instead of test.
    if (io.Directory.current.path.endsWith('test')) {
      packagesPath = io.Directory.current.parent.parent.path;
    } else {
      packagesPath = io.Directory.current.parent.path;
    }

    path = '$packagesPath/$package';
    if (!io.Directory(path).existsSync()) {
      fail('Unable to locate package:$package at $path');
    }
  }
  return path;
}

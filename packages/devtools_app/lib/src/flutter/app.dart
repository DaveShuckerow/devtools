// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../src/framework/framework_core.dart';
import '../../src/globals.dart';
import '../debugger/flutter/debugger_screen.dart';
import '../info/flutter/info_screen.dart';
import '../inspector/flutter/inspector_screen.dart';
import '../performance/flutter/performance_screen.dart';
import '../ui/flutter/service_extension_widgets.dart';
import '../ui/theme.dart' as devtools_theme;
import 'common_widgets.dart';
import 'connect_screen.dart';
import 'navigation.dart';
import 'scaffold.dart';
import 'screen.dart';
import 'theme.dart';

/// Top-level configuration for the app.
@immutable
class DevToolsApp extends StatefulWidget {
  @override
  State<DevToolsApp> createState() => DevToolsAppState();
}

/// Initializer for the [FrameworkCore] and the app's navigation.
///
/// This manages the route generation, and marshalls URL query parameters into
/// flutter route parameters.
// TODO(https://github.com/flutter/devtools/issues/1146): Introduce tests that
// navigate the full app.
class DevToolsAppState extends State<DevToolsApp> {
  ThemeData theme;

  @override
  void initState() {
    super.initState();
    theme = themeFor(isDarkTheme: devtools_theme.isDarkTheme);
  }

  /// Generates routes, separating the path from URL query parameters.
  Route _generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name);
    final path = uri.path;
    print(uri);

    // Update the theme based on the query parameters.
    // TODO(djshuckerow): Update this with a NavigatorObserver to load the
    // new theme a frame earlier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // On desktop, don't change the theme on route changes.
      if (!kIsWeb) return;
      setState(() {
        final themeQueryParameter = uri.queryParameters['theme'];
        // We refer to the legacy theme to make sure the
        // debugging page stays in-sync with the rest of the app.
        devtools_theme.initializeTheme(themeQueryParameter);
        theme = themeFor(isDarkTheme: devtools_theme.isDarkTheme);
      });
    });

    // Provide the appropriate page route.
    if (_routes.containsKey(path)) {
      WidgetBuilder builder =
          (context) => _routes[path](context, uri.queryParameters);
      assert(() {
        builder = (context) => _AlternateCheckedModeBanner(
              builder: (context) => _routes[path](
                context,
                uri.queryParameters,
              ),
            );
        return true;
      }());
      return MaterialPageRoute(settings: settings, builder: builder);
    }
    // Return a page not found.
    return MaterialPageRoute(
      settings: settings,
      builder: (BuildContext context) {
        return DevToolsScaffold.withChild(
          child: Center(
            child: Text(
              'Sorry, $uri was not found.',
              style: Theme.of(context).textTheme.display1,
            ),
          ),
        );
      },
    );
  }

  /// The routes that the app exposes.
  final Map<String, UrlParametersBuilder> _routes = {
    '/': (_, params) => Initializer(
          url: params['uri'],
          builder: (_) => DevToolsScaffold(
            tabs: [
              const InspectorScreen(),
              EmptyScreen.timeline,
              const PerformanceScreen(),
              EmptyScreen.memory,
              const DebuggerScreen(),
              EmptyScreen.logging,
              const InfoScreen(),
            ],
            actions: [
              HotReloadButton(),
              HotRestartButton(),
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
              ),
            ],
          ),
        ),
    '/connect': (_, __) =>
        DevToolsScaffold.withChild(child: ConnectScreenBody()),
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      onGenerateRoute: _generateRoute,
    );
  }
}

typedef UrlParametersBuilder = Widget Function(
    BuildContext, Map<String, String>);

/// Widget that requires business logic to be loaded before building its
/// [builder].
///
/// See [_InitializerState.build] for the logic that determines whether the
/// business logic is loaded.
///
/// Use this widget to wrap pages that require [service.serviceManager] to be
/// connected. As we require additional services to be available, add them
/// here.
class Initializer extends StatefulWidget {
  const Initializer({Key key, this.url, @required this.builder})
      : assert(builder != null),
        super(key: key);

  /// The builder for the widget's children.
  ///
  /// Will only be built if [_InitializerState._checkLoaded] is true.
  final WidgetBuilder builder;

  /// The url to attempt to load a vm service from.
  final String url;

  @override
  _InitializerState createState() => _InitializerState();
}

class _InitializerState extends State<Initializer>
    with SingleTickerProviderStateMixin {
  final List<StreamSubscription> _subscriptions = [];

  /// Checks if the [service.serviceManager] is connected.
  ///
  /// This is a method and not a getter to communicate that its value may
  /// change between successive calls.
  bool _checkLoaded() => serviceManager.hasConnection;

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      serviceManager.onStateChange.listen((_) {
        // Generally, empty setState calls in Flutter should be avoided.
        // However, serviceManager is an implicit part of this state.
        // This setState call is alerting a change in the serviceManager's
        // state.
        setState(() {});
        // If we've become disconnected, attempt to reconnect.
        _navigateToConnectPage();
      }),
    );
    if (widget.url != null) {
      _attemptUrlConnection();
    } else {
      _navigateToConnectPage();
    }
  }

  @override
  void dispose() {
    for (var s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _attemptUrlConnection() async {
    final url = Uri.decodeFull(widget.url);
    print('Decoding url: $url');
    final bool connected = await FrameworkCore.initVmService(
      '',
      explicitUri: Uri.parse(url),
      errorReporter: showErrorSnackBar(context),
    );

    if (!connected) {
      _navigateToConnectPage();
    }
  }

  /// Loads the /connect page if the [service.serviceManager] is not currently connected.
  void _navigateToConnectPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_checkLoaded() && ModalRoute.of(context).isCurrent) {
        print(ModalRoute.of(context).settings);
        // If this route is on top and the app is not loaded, then we navigate to
        // the /connect page to get a VM Service connection for serviceManager.
        // When it completes, the serviceManager will notify this instance.
        Navigator.of(context).pushNamed(
          routeNameWithQueryParams(context, '/connect'),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _checkLoaded()
        ? widget.builder(context)
        : const Center(child: CircularProgressIndicator());
  }
}

/// Displays the checked mode banner in the bottom end corner instead of the
/// top end corner.
///
/// This avoids issues with widgets in the appbar being hidden by the banner
/// in a web or desktop app.
class _AlternateCheckedModeBanner extends StatelessWidget {
  const _AlternateCheckedModeBanner({Key key, this.builder}) : super(key: key);
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Banner(
      message: 'DEBUG',
      textDirection: TextDirection.ltr,
      location: BannerLocation.bottomEnd,
      child: Builder(
        builder: builder,
      ),
    );
  }
}

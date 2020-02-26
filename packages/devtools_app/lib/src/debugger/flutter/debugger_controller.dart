// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../globals.dart';

/// Responsible for managing the debug state of the app.
class DebuggerController {
  VmService _service;

  StreamSubscription<Event> _debugSubscription;

  IsolateRef isolateRef;
  List<ScriptRef> scripts;

  final Map<String, Script> _scriptCache = <String, Script>{};

  final _isPaused = ValueNotifier<bool>(false);
  ValueListenable<bool> get isPaused => _isPaused;

  final _hasFrames = ValueNotifier<bool>(false);
  ValueNotifier<bool> _supportsStepping;
  ValueListenable<bool> get supportsStepping {
    return _supportsStepping ??= () {
      final notifier = ValueNotifier<bool>(_isPaused.value && _hasFrames.value);
      void update() {
        notifier.value = _isPaused.value && _hasFrames.value;
      }

      _isPaused.addListener(update);
      _hasFrames.addListener(update);
      return notifier;
    }();
  }

  Event lastEvent;

  final _breakpoints = ValueNotifier<List<Breakpoint>>([]);
  ValueListenable<List<Breakpoint>> get breakpoints => _breakpoints;

  final _exceptionPauseMode = ValueNotifier<String>(null);
  ValueListenable<String> get exceptionPauseMode => _exceptionPauseMode;

  InstanceRef _reportedException;

  void setVmService(VmService service) {
    _service = service;
    switchToIsolate(serviceManager.isolateManager.selectedIsolate);

    _debugSubscription = _service.onDebugEvent.listen(_handleIsolateEvent);
    serviceManager.isolateManager.onSelectedIsolateChanged
        .listen(switchToIsolate);
  }

  void switchToIsolate(IsolateRef ref) async {
    isolateRef = ref;

    _isPaused.value = false;

    _clearCaches();

    if (ref == null) {
      _breakpoints.value = [];
      return;
    }

    final dynamic result = await _service.getIsolate(isolateRef.id);
    if (result is Isolate) {
      final Isolate isolate = result;

      if (isolate.pauseEvent != null &&
          isolate.pauseEvent.kind != EventKind.kResume) {
        lastEvent = isolate.pauseEvent;
        _reportedException = isolate.pauseEvent.exception;
        _isPaused.value = true;
      }

      _breakpoints.value = isolate.breakpoints;

      _exceptionPauseMode.value = isolate.exceptionPauseMode;
    }
  }

  Future<Success> pause() => _service.pause(isolateRef.id);

  Future<Success> resume() => _service.resume(isolateRef.id);

  Future<Success> stepOver() {
    // Handle async suspensions; issue StepOption.kOverAsyncSuspension.
    final bool useAsyncStepping = lastEvent?.atAsyncSuspension == true;
    return _service.resume(isolateRef.id,
        step: useAsyncStepping
            ? StepOption.kOverAsyncSuspension
            : StepOption.kOver);
  }

  Future<Success> stepIn() {
    return _service.resume(isolateRef.id, step: StepOption.kInto);
  }

  Future<Success> stepOut() {
    return _service.resume(isolateRef.id, step: StepOption.kOut);
  }

  Future<void> clearBreakpoints() async {
    final List<Breakpoint> breakpoints = _breakpoints.value.toList();
    await Future.forEach(breakpoints, (Breakpoint breakpoint) {
      return removeBreakpoint(breakpoint);
    });
  }

  Future<void> addBreakpoint(String scriptId, int line) {
    return _service.addBreakpoint(isolateRef.id, scriptId, line);
  }

  Future<void> addBreakpointByPathFragment(String path, int line) async {
    final ScriptRef ref =
        scripts.firstWhere((ref) => ref.uri.endsWith(path), orElse: () => null);
    if (ref != null) {
      return _service.addBreakpoint(isolateRef.id, ref.id, line);
    }
  }

  Future<void> removeBreakpoint(Breakpoint breakpoint) {
    return _service.removeBreakpoint(isolateRef.id, breakpoint.id);
  }

  Future<void> setExceptionPauseMode(String mode) {
    return _service.setExceptionPauseMode(isolateRef.id, mode);
  }

  Future<Stack> getStack() {
    return _service.getStack(isolateRef.id);
  }

  InstanceRef get reportedException => _reportedException;

  void _handleIsolateEvent(Event event) {
    if (event.isolate.id != isolateRef.id) {
      return;
    }

    _hasFrames.value = event.topFrame != null;
    lastEvent = event;

    switch (event.kind) {
      case EventKind.kResume:
        _isPaused.value = false;
        _reportedException = null;
        break;
      case EventKind.kPauseStart:
      case EventKind.kPauseExit:
      case EventKind.kPauseBreakpoint:
      case EventKind.kPauseInterrupted:
      case EventKind.kPauseException:
      case EventKind.kPausePostRequest:
        _reportedException = event.exception;
        _isPaused.value = true;
        break;
      case EventKind.kBreakpointAdded:
        _breakpoints.value = [..._breakpoints.value, event.breakpoint];
        break;
      case EventKind.kBreakpointResolved:
        _breakpoints.value = [
          for (var b in _breakpoints.value) if (b != event.breakpoint) b,
          event.breakpoint
        ];
        break;
      case EventKind.kBreakpointRemoved:
        _breakpoints.value = [
          for (var b in _breakpoints.value) if (b != event.breakpoint) b
        ];
        break;
    }
  }

  void _clearCaches() {
    _scriptCache.clear();
    lastEvent = null;
    _reportedException = null;
  }

  void dispose() {
    _debugSubscription?.cancel();
  }

  /// Get the populated [Instance] object, given an [InstanceRef].
  ///
  /// The return value can be one of [Instance] or [Sentinel].
  Future<dynamic> getInstance(InstanceRef instanceRef) {
    return _service.getObject(isolateRef.id, instanceRef.id);
  }

  Future<Script> getScript(ScriptRef scriptRef) async {
    if (!_scriptCache.containsKey(scriptRef.id)) {
      _scriptCache[scriptRef.id] =
          await _service.getObject(isolateRef.id, scriptRef.id);
    }

    return _scriptCache[scriptRef.id];
  }

  SourcePosition calculatePosition(Script script, int tokenPos) {
    final List<List<int>> table = script.tokenPosTable;
    if (table == null) {
      return null;
    }

    for (List<int> row in table) {
      if (row == null || row.isEmpty) {
        continue;
      }
      final int line = row.elementAt(0);
      int index = 1;

      while (index < row.length - 1) {
        if (row.elementAt(index) == tokenPos) {
          return SourcePosition(line, row.elementAt(index + 1));
        }
        index += 2;
      }
    }

    return null;
  }

  String commonScriptPrefix;
  LibraryRef rootLib;

  void setRootLib(LibraryRef rootLib) {
    this.rootLib = rootLib;

    String scriptPrefix = rootLib.uri;
    if (scriptPrefix.startsWith('package:')) {
      scriptPrefix = scriptPrefix.substring(0, scriptPrefix.indexOf('/') + 1);
    } else if (scriptPrefix.contains('/lib/')) {
      scriptPrefix =
          scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/lib/'));
      if (scriptPrefix.contains('/')) {
        scriptPrefix =
            scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/') + 1);
      }
    } else if (scriptPrefix.contains('/bin/')) {
      scriptPrefix =
          scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/bin/'));
      if (scriptPrefix.contains('/')) {
        scriptPrefix =
            scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/') + 1);
      }
    } else if (scriptPrefix.contains('/test/')) {
      scriptPrefix =
          scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/test/'));
      if (scriptPrefix.contains('/')) {
        scriptPrefix =
            scriptPrefix.substring(0, scriptPrefix.lastIndexOf('/') + 1);
      }
    } else {
      scriptPrefix = null;
    }

    commonScriptPrefix = scriptPrefix;
  }

  int getLineNumber(Script script, dynamic location) {
    if (script == null || location == null) {
      return null;
    }
    if (location is UnresolvedSourceLocation && location.line != null) {
      return location.line;
    } else if (location is SourceLocation) {
      return calculatePosition(script, location.tokenPos).line;
    }
    throw Exception(
      '$location should be a $UnresolvedSourceLocation or a $SourceLocation',
    );
  }

  String getShortScriptName(String uri) {
    if (commonScriptPrefix == null) {
      return uri;
    }

    if (!uri.startsWith(commonScriptPrefix)) {
      return uri;
    }

    if (commonScriptPrefix.startsWith('package:')) {
      return uri.substring('package:'.length);
    } else {
      return uri.substring(commonScriptPrefix.length);
    }
  }

  void updateFrom(Isolate isolate) {
    _breakpoints.value = isolate.breakpoints;
  }
}

class SourcePosition {
  SourcePosition(this.line, [this.column]);

  final int line;
  final int column;

  @override
  String toString() => '$line $column';
}

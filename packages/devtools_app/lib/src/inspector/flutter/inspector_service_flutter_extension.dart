import 'package:flutter/rendering.dart';
import 'package:vm_service/vm_service.dart';

import '../inspector_service.dart';

extension InspectorFlutterService on ObjectGroup {
  Future<InstanceRef> invokeTweakFlexProperties(
    InspectorInstanceRef ref,
    MainAxisAlignment mainAxisAlignment,
    CrossAxisAlignment crossAxisAlignment,
  ) async {
    final command = '((){'
        '  dynamic object = WidgetInspectorService.instance.toObject("${ref?.id}");'
        '  final render = object.renderObject;'
        '  render.mainAxisAlignment = $mainAxisAlignment;'
        '  render.crossAxisAlignment = $crossAxisAlignment;'
        '  render.markNeedsLayout();'
        '})()';
    final val = await _debugTime(
      'invokeTweakFlexProperties',
      () => inspectorLibrary.eval(command, isAlive: this),
    );
    return val;
  }

  Future<InstanceRef> invokeTweakFlexFactor(
      InspectorInstanceRef ref, int flexFactor) async {
    final command = '((){'
        '  dynamic object = WidgetInspectorService.instance.toObject("${ref?.id}");'
        '  final render = object.renderObject;'
        '  final FlexParentData parentData = render.parentData;'
        '  parentData.flex = $flexFactor;'
        '  render.markNeedsLayout();'
        '})()';
    final val = await _debugTime(
      'invokeTweakFlexFactor',
      () => inspectorLibrary.eval(command, isAlive: this),
    );
    return val;
  }
}

Future<T> _debugTime<T>(String name, Future<T> Function() toTime) async {
  DateTime start;
  assert(() {
    start = DateTime.now();
    print('Starting $name at $start');
    return true;
  }());

  final result = await toTime();

  assert(() {
    final end = DateTime.now();
    print(
        'Finishing $name at $end\nTook ${end.millisecondsSinceEpoch - start.millisecondsSinceEpoch}ms');
    return true;
  }());
  return result;
}

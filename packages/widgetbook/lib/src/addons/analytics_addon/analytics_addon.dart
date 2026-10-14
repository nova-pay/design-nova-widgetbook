import 'package:flutter/widgets.dart';

import '../../fields/fields.dart';
import '../common/common.dart';
import 'analytics_layer.dart';
import 'analytics_marker.dart';

/// Returns the markers for what is on screen. [context] is inside the
/// workbench, below the use case's app builder.
typedef AnalyticsResolver =
    List<AnalyticsMarker> Function(
      BuildContext context,
    );

/// Shows the analytics events of the current use case as cards around the
/// workbench, each linked to the widget that sends it. A button in the
/// workbench's corner turns the cards on and off; they can be dragged
/// anywhere.
///
/// The events come from [resolve], which the app provides: Widgetbook knows
/// nothing about how analytics are tracked. The workbench is rescanned every
/// [rescanInterval] and whenever [refresh] notifies, so cards follow widgets
/// that move and pick up sheets and routes that open.
///
/// Put this addon first in the list so it wraps the others (e.g. the device
/// frame) and the cards can sit beside the device.
class AnalyticsAddon extends WidgetbookAddon<bool> {
  /// Creates the addon. [resolve] lists the markers for what is on screen.
  AnalyticsAddon({
    required this.resolve,
    this.refresh,
    this.initialEnabled = false,
    this.rescanInterval = const Duration(milliseconds: 300),
    this.color = const Color(0xFF5B5BD6),
  }) : super(name: 'Analytics');

  /// Lists the markers for what is on screen.
  final AnalyticsResolver resolve;

  /// Rescans the workbench when it notifies, e.g. when an event is sent.
  final Listenable? refresh;

  /// Whether the cards are shown before the toggle is used.
  final bool initialEnabled;

  /// How often the workbench is rescanned while the addon is on screen.
  final Duration rescanInterval;

  /// Accent colour of the toggle and of markers without their own.
  final Color color;

  @override
  List<Field<bool>> get fields {
    return [BooleanField(name: 'enabled', initialValue: initialEnabled)];
  }

  @override
  bool valueFromQueryGroup(Map<String, String> group) {
    return valueOf<bool>('enabled', group) ?? initialEnabled;
  }

  @override
  Widget buildUseCase(BuildContext context, Widget child, bool setting) {
    return AnalyticsLayer(
      enabled: setting,
      onToggle: (context, enabled) =>
          fields.first.updateField(context, groupName, enabled),
      resolve: resolve,
      refresh: refresh,
      rescanInterval: rescanInterval,
      color: color,
      child: child,
    );
  }
}

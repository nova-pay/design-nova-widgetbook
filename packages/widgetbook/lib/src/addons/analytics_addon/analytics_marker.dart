import 'package:flutter/widgets.dart';

/// An analytics event shown by the `AnalyticsAddon`, as a card that can be
/// dragged around the workbench.
///
/// A marker with a [target] is drawn next to that widget with a line to it,
/// e.g. the event a button sends when tapped. A marker without one is listed
/// at the top of the workbench, e.g. a screen view that was already sent.
@immutable
class AnalyticsMarker {
  /// Creates a marker for the event [title] with its [properties].
  const AnalyticsMarker({
    required this.id,
    required this.title,
    this.properties = const {},
    this.badge,
    this.target,
    this.color,
  });

  /// Identifies the marker across rescans, so a card keeps the position it
  /// was dragged to.
  final String id;

  /// The event name, e.g. `button.clicked`.
  final String title;

  /// The event properties, in display order.
  final Map<String, String> properties;

  /// A short note in the card's corner, e.g. `on tap` or `sent ×2`.
  final String? badge;

  /// The widget the event belongs to.
  final Element? target;

  /// The card's accent colour. Defaults to the addon's.
  final Color? color;
}

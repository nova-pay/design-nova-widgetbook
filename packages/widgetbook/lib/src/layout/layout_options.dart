import 'package:flutter/widgets.dart';

/// Options that change how the Widgetbook shell is laid out.
///
/// The defaults keep the original Widgetbook layout.
class WidgetbookLayoutOptions {
  /// Creates a [WidgetbookLayoutOptions].
  const WidgetbookLayoutOptions({
    this.topBar,
    this.navigationPanelWidth,
    this.showNavigationSearch = true,
    this.showNavigationIcons = true,
    this.showStatsBanner = true,
  });

  /// An optional full-width bar shown above all panels.
  ///
  /// It is built below the `WidgetbookScope`, so it can read and update
  /// the state, for example to drive the search query with
  /// `WidgetbookState.of(context).updateQuery`.
  final Widget? topBar;

  /// When set, the navigation panel has this fixed width and the panels are
  /// drawn flush (no cards, separated by 1px dividers) instead of as
  /// resizable cards.
  final double? navigationPanelWidth;

  /// Whether the search field is shown at the top of the navigation panel.
  final bool showNavigationSearch;

  /// Whether folder, component and use-case icons are shown in the
  /// navigation tree.
  final bool showNavigationIcons;

  /// Whether the components/use-cases counter is shown at the bottom of the
  /// navigation panel.
  final bool showStatsBanner;
}

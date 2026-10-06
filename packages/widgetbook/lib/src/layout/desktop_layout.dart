import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:resizable_widget/resizable_widget.dart';

import '../settings/settings.dart';
import '../state/state.dart';
import '../widgetbook_theme.dart';
import 'base_layout.dart';

/// The [DesktopLayout] is a layout for desktop devices that allows
/// displaying the navigation, addons, knobs, and workbench in a
/// resizable layout.
@internal
class DesktopLayout extends StatelessWidget implements BaseLayout {
  const DesktopLayout({
    super.key,
    required this.navigationBuilder,
    required this.addonsBuilder,
    required this.knobsBuilder,
    required this.workbench,
  });

  final Widget? Function(BuildContext context) navigationBuilder;
  final List<Widget> Function(BuildContext context) addonsBuilder;
  final List<Widget> Function(BuildContext context) knobsBuilder;
  final Widget workbench;

  @override
  Widget build(BuildContext context) {
    final state = WidgetbookState.of(context);
    final theme = WidgetbookTheme.of(context);

    const kSidePanelPercentage = 0.2;
    const kWorkbenchPercentage = 1 - 2 * kSidePanelPercentage;

    // A custom navigation may build nothing for some pages (no panel).
    final navigation = state.canShowPanel(LayoutPanel.navigation)
        ? navigationBuilder(context)
        : null;
    final showNavigationPanel = navigation != null;
    // Knobs and addons don't apply to documentation pages. The docs-style
    // layout (fixed navigation width) also hides them on the home page.
    final useCase = state.useCase;
    final navigationPanelWidth = state.layoutOptions.navigationPanelWidth;
    final hasSettings = useCase == null
        ? navigationPanelWidth == null
        : !useCase.isDocPage;
    final showSettingsPanel =
        hasSettings &&
        (state.canShowPanel(LayoutPanel.addons) ||
            state.canShowPanel(LayoutPanel.knobs));

    final settingsPanel = SettingsPanel(
      settings: [
        if (state.canShowPanel(LayoutPanel.knobs)) ...{
          SettingsPanelData(
            name: 'Knobs',
            builder: knobsBuilder,
          ),
        },
        if (state.canShowPanel(LayoutPanel.addons) && state.addons != null) ...{
          SettingsPanelData(
            name: 'Addons',
            builder: addonsBuilder,
          ),
        },
      ],
    );

    if (navigationPanelWidth != null) {
      final divider = BorderSide(color: theme.dividerColor);

      return ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showNavigationPanel)
              Material(
                color: theme.colorScheme.surface,
                shape: Border(right: divider),
                child: SizedBox(
                  width: navigationPanelWidth,
                  child: navigation,
                ),
              ),
            Expanded(
              child: ResizableLayout(
                separatorColor: theme.dividerColor,
                separatorSize: 1,
                items: [
                  ResizableLayoutItem(
                    percentage: 0.75,
                    child: workbench,
                  ),
                  if (showSettingsPanel)
                    ResizableLayoutItem(
                      percentage: 0.25,
                      child: Material(
                        color: theme.colorScheme.surface,
                        child: settingsPanel,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: ResizableLayout(
        items: [
          if (showNavigationPanel)
            ResizableLayoutItem(
              percentage: kSidePanelPercentage,
              child: Card(
                child: navigation,
              ),
            ),
          ResizableLayoutItem(
            percentage: kWorkbenchPercentage,
            child: workbench,
          ),
          if (showSettingsPanel)
            ResizableLayoutItem(
              percentage: kSidePanelPercentage,
              child: Card(
                child: settingsPanel,
              ),
            ),
        ],
      ),
    );
  }
}

@internal
class ResizableLayoutItem {
  const ResizableLayoutItem({
    required this.percentage,
    required this.child,
  });

  final double percentage;
  final Widget child;
}

/// An improved API for [ResizableWidget] that allows passing both percentage
/// and child in a single object, allowing to easily add or remove items.
/// Also distributes the remaining space equally among all items.
@internal
class ResizableLayout extends StatelessWidget {
  const ResizableLayout({
    super.key,
    required this.items,
    this.separatorColor,
    this.separatorSize = 2,
  });

  final List<ResizableLayoutItem> items;

  /// Defaults to the theme's scaffold background color.
  final Color? separatorColor;
  final double separatorSize;

  @override
  Widget build(BuildContext context) {
    final totalPercentage = items.fold(0.0, (sum, x) => sum + x.percentage);
    final remainingPercentage = 1 - totalPercentage;
    final extraPercentage = remainingPercentage / items.length;

    return ResizableWidget(
      separatorSize: separatorSize,
      separatorColor:
          separatorColor ?? WidgetbookTheme.of(context).scaffoldBackgroundColor,
      percentages: items.map((x) => x.percentage + extraPercentage).toList(),
      children: items.map((x) => x.child).toList(),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../../widgetbook_theme.dart';
import '../icons/icons.dart';
import '../icons/resolve_icon.dart';
import '../nodes/nodes.dart';

@internal
class NavigationTreeTile extends StatelessWidget {
  const NavigationTreeTile({
    super.key,
    required this.node,
    this.onTap,
    this.isExpanded = false,
    this.isSelected = false,
    this.enableLeafComponents = true,
    this.showIcon = true,
  });

  static const indentation = 24.0;
  static const height = 32.0;

  final WidgetbookNode node;
  final VoidCallback? onTap;
  final bool isExpanded;
  final bool isSelected;
  final bool enableLeafComponents;
  final bool showIcon;

  /// Depth in the tree, ignoring categories without a page: they are
  /// rendered as labels, so their children start without indentation.
  /// Categories with a page are items, so their children are indented.
  int get _visualDepth => node.nodesPath
      .where(
        (n) => !n.isRoot && !(n is WidgetbookCategory && n.page == null),
      )
      .length;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    final theme = WidgetbookTheme.of(context);
    final colorScheme = theme.colorScheme;
    final isLeafComponent =
        enableLeafComponents &&
        node is WidgetbookComponent &&
        node.children?.length == 1;
    final isGroup = !node.isLeaf && !isLeafComponent;

    // Groups (folders, components with many use-cases) read stronger than
    // the items inside them; the selected item is the strongest.
    final foregroundColor = isSelected
        ? colorScheme.onSecondaryContainer
        : isGroup
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;
    final fontWeight = isSelected || isGroup
        ? FontWeight.w500
        : FontWeight.w400;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: isSelected ? colorScheme.secondaryContainer : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: IconTheme.merge(
          data: IconThemeData(color: foregroundColor),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: foregroundColor,
              fontWeight: fontWeight,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: max(_visualDepth - 1, 0) * indentation,
                ),
                SizedBox(
                  width: indentation,
                  // Categories are always expanded, so they have no expander.
                  child: isGroup && node is! WidgetbookCategory
                      ? ExpanderIcon(
                          isExpanded: isExpanded,
                        )
                      : null,
                ),
                if (showIcon) ...[
                  SizedBox(
                    width: indentation,
                    child: resolveIcon(node),
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                ],
                Expanded(
                  child: Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

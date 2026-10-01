import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../../widgetbook_theme.dart';
import '../nodes/nodes.dart';
import 'navigation_tree_tile.dart';

@internal
class NavigationTreeNode extends StatefulWidget {
  const NavigationTreeNode({
    super.key,
    required this.node,
    this.selectedNode,
    this.onNodeSelected,
    this.enableLeafComponents = true,
    this.showIcons = true,
    this.forceExpanded = false,
  });

  final WidgetbookNode node;
  final WidgetbookNode? selectedNode;
  final ValueChanged<WidgetbookNode>? onNodeSelected;
  final bool enableLeafComponents;
  final bool showIcons;

  /// Expands the node regardless of [WidgetbookNode.isInitiallyExpanded],
  /// e.g. while search results are shown.
  final bool forceExpanded;

  @override
  State<NavigationTreeNode> createState() => _NavigationTreeNodeState();
}

class _NavigationTreeNodeState extends State<NavigationTreeNode> {
  late bool isExpanded;

  @override
  void initState() {
    super.initState();

    final selectedPath = widget.selectedNode?.path;
    final containsSelection =
        selectedPath != null && selectedPath.startsWith('${widget.node.path}/');

    isExpanded =
        widget.forceExpanded ||
        widget.node.isInitiallyExpanded ||
        containsSelection;
  }

  NavigationTreeNode _buildChild(WidgetbookNode child) {
    return NavigationTreeNode(
      node: child,
      selectedNode: widget.selectedNode,
      onNodeSelected: widget.onNodeSelected,
      enableLeafComponents: widget.enableLeafComponents,
      showIcons: widget.showIcons,
      forceExpanded: widget.forceExpanded,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Categories are rendered as always-expanded section headers.
    if (widget.node is WidgetbookCategory) {
      return _CategorySection(
        name: widget.node.name,
        children: widget.node.children?.map(_buildChild).toList() ?? [],
      );
    }

    const animationDuration = Duration(
      milliseconds: 200,
    );

    final isLeafComponent =
        widget.enableLeafComponents &&
        widget.node is WidgetbookComponent &&
        widget.node.children?.length == 1;

    // Redirect interactions to the use-case of the leaf component,
    // so that when it's clicked, the route is updated to the use-case
    // of the leaf component, and not the leaf component itself.
    final targetNode = isLeafComponent
        ? widget.node.children!.first
        : widget.node;

    return Column(
      children: [
        NavigationTreeTile(
          node: widget.node,
          isExpanded: isExpanded,
          isSelected: targetNode.path == widget.selectedNode?.path,
          enableLeafComponents: widget.enableLeafComponents,
          showIcon: widget.showIcons,
          onTap: () {
            setState(() => isExpanded = !isExpanded);
            widget.onNodeSelected?.call(targetNode);
          },
        ),
        if (widget.node.children != null && !isLeafComponent)
          ClipRect(
            child: AnimatedSlide(
              duration: animationDuration,
              curve: Curves.easeInOut,
              offset: Offset(0, isExpanded ? 0 : -1),
              child: AnimatedAlign(
                duration: animationDuration,
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                heightFactor: isExpanded ? 1 : 0,
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.node.children!.length,
                  shrinkWrap: true,
                  itemBuilder: (context, index) =>
                      _buildChild(widget.node.children![index]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.name,
    required this.children,
  });

  final String name;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final style = WidgetbookTheme.of(context).textTheme.labelMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Text(
            name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(
              letterSpacing: (style.fontSize ?? 11) * 0.08,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

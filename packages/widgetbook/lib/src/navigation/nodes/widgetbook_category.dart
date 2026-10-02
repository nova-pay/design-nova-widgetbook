import 'widgetbook_node.dart';
import 'widgetbook_use_case.dart';

/// A top-level group of the navigation tree, rendered as a section header.
///
/// When a [page] is given, the header itself is clickable and opens that
/// use case (e.g. an overview page for the section).
class WidgetbookCategory extends WidgetbookNode {
  /// Creates a [WidgetbookCategory] node.
  WidgetbookCategory({
    required super.name,
    required List<WidgetbookNode> children,
    this.page,
    super.isInitiallyExpanded,
  }) : super(
         // The page is a regular child so it gets a path and a route.
         children: [if (page != null) page, ...children],
       );

  /// The use case opened by clicking the section header, if any.
  ///
  /// It is the first entry of [children] and is not listed as a separate
  /// item in the navigation.
  final WidgetbookUseCase? page;

  /// [children] without the [page].
  List<WidgetbookNode> get entries =>
      children!.where((child) => child != page).toList();

  @override
  WidgetbookCategory copyWith({
    String? name,
    List<WidgetbookNode>? children,
  }) {
    final newChildren = children ?? this.children!;
    final keepsPage = page != null && newChildren.contains(page);

    return WidgetbookCategory(
      name: name ?? this.name,
      page: keepsPage ? page : null,
      children: newChildren.where((child) => child != page).toList(),
      isInitiallyExpanded: isInitiallyExpanded,
    );
  }
}

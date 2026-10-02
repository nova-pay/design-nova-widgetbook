import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widgetbook/src/navigation/navigation.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  group('$WidgetbookCategory with a page', () {
    WidgetbookCategory category() => WidgetbookCategory(
      name: 'Foundations',
      page: WidgetbookUseCase(
        name: 'Overview',
        builder: (_) => const Text('Foundations page'),
      ),
      children: [
        WidgetbookComponent(
          name: 'Colors',
          useCases: [
            WidgetbookUseCase(
              name: 'Default',
              builder: (_) => const Text('Colors page'),
            ),
          ],
        ),
      ],
    );

    test('keeps the page as its first child, out of entries', () {
      final node = category();

      expect(node.children!.first, node.page);
      expect(node.entries.map((e) => e.name), ['Colors']);
    });

    test('copyWith keeps the page only if it is still a child', () {
      final node = category();

      expect(node.copyWith(children: node.children).page, node.page);
      expect(node.copyWith(children: node.entries).page, isNull);
    });

    test('the page gets a route under the category', () {
      final root = WidgetbookRoot(children: [category()]);

      expect(root.table.keys, contains('foundations/overview'));
    });

    testWidgets(
      'given a category with a page, '
      'then its header is an item that opens the page',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          Widgetbook.material(
            directories: [category()],
            layoutOptions: const WidgetbookLayoutOptions(
              navigationPanelWidth: 280,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Rendered as an item, not as an uppercase label, and the page is
        // not listed separately.
        expect(find.text('FOUNDATIONS'), findsNothing);
        expect(
          find.widgetWithText(NavigationTreeTile, 'Overview'),
          findsNothing,
        );

        await tester.tap(
          find.widgetWithText(NavigationTreeTile, 'Foundations'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Foundations page'), findsOneWidget);
        expect(
          tester
              .widget<NavigationTreeTile>(
                find.widgetWithText(NavigationTreeTile, 'Foundations'),
              )
              .isSelected,
          isTrue,
        );

        // Children are indented under the section item.
        final sectionX = tester.getTopLeft(find.text('Foundations')).dx;
        final childX = tester.getTopLeft(find.text('Colors')).dx;
        expect(childX, greaterThan(sectionX));
      },
    );
  });
}

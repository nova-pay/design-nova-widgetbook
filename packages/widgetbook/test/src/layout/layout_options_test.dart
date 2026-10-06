import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widgetbook/src/navigation/navigation.dart';
import 'package:widgetbook/src/settings/settings_panel.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  group('$WidgetbookLayoutOptions', () {
    final directories = [
      WidgetbookCategory(
        name: 'Components',
        children: [
          WidgetbookFolder(
            name: 'Buttons',
            isInitiallyExpanded: false,
            children: [
              WidgetbookComponent(
                name: 'Button',
                useCases: [
                  WidgetbookUseCase(
                    name: 'Default',
                    builder: (_) => const SizedBox(),
                  ),
                  WidgetbookUseCase(
                    name: 'Disabled',
                    builder: (_) => const SizedBox(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ];

    Future<void> pumpDesktop(
      WidgetTester tester, {
      WidgetbookLayoutOptions options = const WidgetbookLayoutOptions(),
      String initialRoute = '/',
    }) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        Widgetbook.material(
          directories: directories,
          initialRoute: initialRoute,
          layoutOptions: options,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'given default options, '
      'then search, icons, stats banner and cards are shown',
      (tester) async {
        await pumpDesktop(tester);

        expect(find.byType(SearchField), findsOneWidget);
        expect(find.byType(StatsBanner), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byType(NavigationPanel),
            matching: find.byType(Card),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'given a top bar, '
      'then it is shown above the navigation panel',
      (tester) async {
        await pumpDesktop(
          tester,
          options: const WidgetbookLayoutOptions(
            topBar: SizedBox(height: 56, child: Text('Top bar')),
          ),
        );

        final topBarDy = tester.getTopLeft(find.text('Top bar')).dy;
        final navigationDy = tester.getTopLeft(find.byType(NavigationPanel)).dy;

        expect(topBarDy < navigationDy, isTrue);
      },
    );

    testWidgets(
      'given a navigation panel width, '
      'then the panel has that fixed width and no cards are used',
      (tester) async {
        await pumpDesktop(
          tester,
          options: const WidgetbookLayoutOptions(navigationPanelWidth: 280),
        );

        final navigation = find.byType(NavigationPanel);

        expect(tester.getSize(navigation).width, 280);
        expect(
          find.ancestor(of: navigation, matching: find.byType(Card)),
          findsNothing,
        );
      },
    );

    testWidgets(
      'given search, icons and stats banner are disabled, '
      'then they are not shown',
      (tester) async {
        await pumpDesktop(
          tester,
          options: const WidgetbookLayoutOptions(
            showNavigationSearch: false,
            showNavigationIcons: false,
            showStatsBanner: false,
          ),
        );

        expect(find.byType(SearchField), findsNothing);
        expect(find.byType(StatsBanner), findsNothing);
        expect(find.byType(ComponentIcon), findsNothing);
      },
    );

    testWidgets(
      'given a category, '
      'then it is rendered as an uppercase section header',
      (tester) async {
        await pumpDesktop(tester);

        expect(find.text('COMPONENTS'), findsOneWidget);
        expect(find.text('Components'), findsNothing);
      },
    );

    testWidgets(
      'given a collapsed folder that contains the selected use case, '
      'then the folder is expanded on start',
      (tester) async {
        await pumpDesktop(
          tester,
          initialRoute: '/?path=components/buttons/button/disabled',
        );

        final tile = find.widgetWithText(NavigationTreeTile, 'Disabled');
        expect(tester.getSize(tile).height, greaterThan(0));
        expect(
          tester.widget<NavigationTreeTile>(tile).isSelected,
          isTrue,
        );
      },
    );

    testWidgets(
      'given a navigation panel width and no selected use case, '
      'then the settings panel is hidden on the home page',
      (tester) async {
        await pumpDesktop(
          tester,
          options: const WidgetbookLayoutOptions(navigationPanelWidth: 280),
        );

        expect(find.byType(SettingsPanel), findsNothing);
      },
    );

    testWidgets(
      'given a navigation builder, '
      'then it replaces the navigation tree and can navigate',
      (tester) async {
        await pumpDesktop(
          tester,
          options: WidgetbookLayoutOptions(
            navigationPanelWidth: 280,
            navigationBuilder: (context) => TextButton(
              onPressed: () => WidgetbookState.of(
                context,
              ).updatePath('components/buttons/button/disabled'),
              child: const Text('Custom nav'),
            ),
          ),
        );

        expect(find.text('Custom nav'), findsOneWidget);
        expect(find.byType(NavigationPanel), findsNothing);

        await tester.tap(find.text('Custom nav'));
        await tester.pumpAndSettle();

        expect(
          WidgetbookState.of(
            tester.element(find.text('Custom nav')),
          ).path,
          'components/buttons/button/disabled',
        );
      },
    );

    testWidgets(
      'given a navigation builder that returns null, '
      'then no navigation panel is shown',
      (tester) async {
        await pumpDesktop(
          tester,
          options: WidgetbookLayoutOptions(
            navigationPanelWidth: 280,
            navigationBuilder: (_) => null,
          ),
        );

        expect(find.byType(NavigationPanel), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 280,
          ),
          findsNothing,
        );
      },
    );
  });
}

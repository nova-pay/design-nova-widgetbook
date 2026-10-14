import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widgetbook/src/layout/desktop_layout.dart';
import 'package:widgetbook/src/navigation/navigation.dart';
import 'package:widgetbook/src/settings/settings_panel.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  group(
    '$DesktopLayout',
    () {
      for (final (width, expected) in [(1600.0, 325.0), (900.0, 280.0)]) {
        testWidgets(
          'given a fixed-width navigation panel on a ${width.round()}px '
          'window, then the settings panel is ${expected.round()}px wide',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);

            await tester.pumpWidget(
              Widgetbook.material(
                initialRoute: '/?path=widget/default',
                layoutOptions: const WidgetbookLayoutOptions(
                  navigationPanelWidth: 300,
                ),
                directories: [
                  WidgetbookComponent(
                    name: 'Widget',
                    useCases: [
                      WidgetbookUseCase(
                        name: 'Default',
                        builder: (_) => const SizedBox(),
                      ),
                    ],
                  ),
                ],
              ),
            );
            await tester.pumpAndSettle();

            expect(
              tester.getSize(find.byType(SettingsPanel)).width,
              closeTo(expected, 2),
            );
          },
        );
      }

      testWidgets(
        'given an empty panels query parameter, '
        'then navigation and settings panels are not displayed',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            const Widgetbook.material(
              directories: [],
              initialRoute: '?panels=',
            ),
          );

          await tester.pumpAndSettle();

          expect(find.byType(NavigationPanel), findsNothing);
          expect(find.byType(SettingsPanel), findsNothing);

          addTearDown(tester.view.resetPhysicalSize);
        },
      );

      testWidgets(
        'given a panels query parameter with no navigation, '
        'then navigation panel is not displayed',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            const Widgetbook.material(
              directories: [],
              initialRoute: '?panels=addons,knobs',
            ),
          );

          await tester.pumpAndSettle();

          expect(find.byType(NavigationPanel), findsNothing);

          addTearDown(tester.view.resetPhysicalSize);
        },
      );

      testWidgets(
        'given a panels query parameter with no addons or knobs, '
        'then settings panel is not displayed',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            const Widgetbook.material(
              directories: [],
              initialRoute: '?panels=navigation',
            ),
          );

          await tester.pumpAndSettle();

          expect(find.byType(SettingsPanel), findsNothing);

          addTearDown(tester.view.resetPhysicalSize);
        },
      );

      testWidgets(
        'given a panels query parameter with no addons, '
        'then addons tab in settings panel is not displayed',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            const Widgetbook.material(
              directories: [],
              initialRoute: '?panels=knobs',
            ),
          );

          await tester.pumpAndSettle();

          expect(find.text('Addons'), findsNothing);

          addTearDown(tester.view.resetPhysicalSize);
        },
      );

      testWidgets(
        'given a panels query parameter with no knobs, '
        'then knobs tab in settings panel is not displayed',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            const Widgetbook.material(
              directories: [],
              initialRoute: '?panels=addons',
            ),
          );

          await tester.pumpAndSettle();

          expect(find.text('Knobs'), findsNothing);

          addTearDown(tester.view.resetPhysicalSize);
        },
      );
    },
  );
}

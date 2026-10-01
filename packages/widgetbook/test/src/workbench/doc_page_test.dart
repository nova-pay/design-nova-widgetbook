import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widgetbook/src/settings/settings_panel.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  group('$WidgetbookUseCase.isDocPage', () {
    var appBuilderCalls = 0;

    Widget appBuilder(BuildContext context, Widget child) {
      appBuilderCalls++;
      return KeyedSubtree(key: const Key('app-builder'), child: child);
    }

    final directories = [
      WidgetbookComponent(
        name: 'Docs',
        useCases: [
          WidgetbookUseCase(
            name: 'Page',
            isDocPage: true,
            builder: (_) => const Text('Doc page body'),
          ),
          WidgetbookUseCase(
            name: 'Widget',
            builder: (_) => const Text('Widget preview'),
          ),
        ],
      ),
    ];

    Future<void> pump(WidgetTester tester, String path) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      appBuilderCalls = 0;
      await tester.pumpWidget(
        Widgetbook(
          directories: directories,
          appBuilder: appBuilder,
          initialRoute: '/?path=$path',
          addons: [AlignmentAddon()],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'given a doc page, '
      'then it is rendered without app builder and settings panel',
      (tester) async {
        await pump(tester, 'docs/page');

        expect(find.text('Doc page body'), findsOneWidget);
        expect(appBuilderCalls, 0);
        expect(find.byType(SettingsPanel), findsNothing);
      },
    );

    testWidgets(
      'given a regular use case, '
      'then the app builder and settings panel are used',
      (tester) async {
        await pump(tester, 'docs/widget');

        expect(find.text('Widget preview'), findsOneWidget);
        expect(appBuilderCalls, greaterThan(0));
        expect(find.byType(SettingsPanel), findsOneWidget);
      },
    );
  });
}

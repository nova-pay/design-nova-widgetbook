import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../helper/tester_extension.dart';

void main() {
  group(
    '$AnalyticsAddon',
    () {
      final payKey = GlobalKey();

      AnalyticsAddon addonWith(List<AnalyticsMarker> Function() markers) {
        return AnalyticsAddon(resolve: (_) => markers());
      }

      List<AnalyticsMarker> markers() => [
        AnalyticsMarker(
          id: 'pay',
          title: 'button.clicked',
          badge: 'on tap',
          properties: const {'button.id': 'pay', 'screen.id': 'checkout'},
          target: payKey.currentContext as Element?,
        ),
        const AnalyticsMarker(
          id: 'viewed',
          title: 'screen.viewed',
          badge: 'sent',
          properties: {'screen.id': 'checkout'},
        ),
      ];

      Widget useCase() {
        return Builder(
          builder: (context) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  key: payKey,
                  width: 120,
                  height: 40,
                  child: const Text('Pay'),
                ),
                TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const SizedBox(
                      height: 200,
                      child: Text('Sheet'),
                    ),
                  ),
                  child: const Text('Open sheet'),
                ),
              ],
            ),
          ),
        );
      }

      Future<void> pumpAddon(
        WidgetTester tester,
        AnalyticsAddon addon, {
        Map<String, String> queryParams = const {},
      }) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidgetWithQueryParams(
          queryParams: {...queryParams},
          builder: (context) {
            final state = WidgetbookState.of(context);
            final setting = addon.valueFromQueryGroup(
              FieldCodec.decodeQueryGroup(state.queryParams[addon.groupName]),
            );
            return addon.buildUseCase(context, useCase(), setting);
          },
        );
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> rescan(WidgetTester tester) async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      test(
        'given a query group, '
        'then [valueFromQueryGroup] reads whether it is enabled',
        () {
          final addon = addonWith(() => []);

          expect(addon.valueFromQueryGroup({'enabled': 'true'}), isTrue);
          expect(addon.valueFromQueryGroup({'enabled': 'false'}), isFalse);
          expect(addon.valueFromQueryGroup({}), isFalse);
        },
      );

      testWidgets(
        'given the addon is off, '
        'then only the toggle is shown',
        (tester) async {
          await pumpAddon(tester, addonWith(markers));

          expect(find.text('Analytics'), findsOneWidget);
          expect(find.text('button.clicked'), findsNothing);
        },
      );

      testWidgets(
        'when the toggle is tapped, '
        'then a card is shown for each marker',
        (tester) async {
          await pumpAddon(tester, addonWith(markers));

          await tester.tap(find.text('Analytics'));
          await rescan(tester);

          expect(find.text('button.clicked'), findsOneWidget);
          expect(find.text('on tap'), findsOneWidget);
          expect(find.text('button.id'), findsOneWidget);
          expect(find.text('pay'), findsOneWidget);
          expect(find.text('screen.viewed'), findsOneWidget);
          expect(find.text('2'), findsOneWidget);

          await tester.tap(find.text('Analytics'));
          await rescan(tester);

          expect(find.text('button.clicked'), findsNothing);
        },
      );

      testWidgets(
        'given a marker with a target, '
        'then its card is in a side column, level with the target',
        (tester) async {
          await pumpAddon(
            tester,
            addonWith(markers),
            queryParams: {'analytics': '{enabled:true}'},
          );

          final target = tester.getRect(find.byKey(payKey));
          final card = tester.getRect(
            find
                .ancestor(
                  of: find.text('button.clicked'),
                  matching: find.byType(AnimatedContainer),
                )
                .first,
          );

          expect(card.left, 16);
          expect(card.overlaps(target), isFalse);
          expect(card.center.dy, closeTo(target.center.dy, 1));
        },
      );

      testWidgets(
        'given a marker without a target, '
        'then its card is listed at the top left',
        (tester) async {
          await pumpAddon(
            tester,
            addonWith(markers),
            queryParams: {'analytics': '{enabled:true}'},
          );

          final card = tester.getRect(
            find
                .ancestor(
                  of: find.text('screen.viewed'),
                  matching: find.byType(AnimatedContainer),
                )
                .first,
          );

          expect(card.topLeft, const Offset(16, 16));
        },
      );

      testWidgets(
        'when a card is dragged, '
        'then it moves, and a double tap puts it back',
        (tester) async {
          await pumpAddon(
            tester,
            addonWith(markers),
            queryParams: {'analytics': '{enabled:true}'},
          );

          Rect cardRect() => tester.getRect(
            find
                .ancestor(
                  of: find.text('button.clicked'),
                  matching: find.byType(AnimatedContainer),
                )
                .first,
          );

          final before = cardRect();
          await tester.drag(find.text('button.clicked'), const Offset(80, 60));
          await rescan(tester);

          expect(cardRect().topLeft, before.topLeft + const Offset(80, 60));

          await tester.tap(find.text('button.clicked'));
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tap(find.text('button.clicked'));
          await rescan(tester);

          expect(cardRect().topLeft, before.topLeft);
        },
      );

      testWidgets(
        'given a bottom sheet is open, '
        'then the cards and the toggle stay above it',
        (tester) async {
          await pumpAddon(
            tester,
            addonWith(markers),
            queryParams: {'analytics': '{enabled:true}'},
          );

          await tester.tap(find.text('Open sheet'));
          await tester.pumpAndSettle();
          expect(find.text('Sheet'), findsOneWidget);

          expect(find.text('button.clicked').hitTestable(), findsOneWidget);
          await tester.tap(find.text('Analytics'));
          await rescan(tester);

          expect(find.text('button.clicked'), findsNothing);
          expect(find.text('Sheet'), findsOneWidget);
        },
      );

      testWidgets(
        'when refresh notifies, '
        'then the cards are rescanned without waiting for the interval',
        (tester) async {
          final refresh = ChangeNotifier();
          addTearDown(refresh.dispose);
          var titles = <String>['first'];
          final addon = AnalyticsAddon(
            refresh: refresh,
            rescanInterval: const Duration(hours: 1),
            resolve: (_) => [
              for (final title in titles)
                AnalyticsMarker(id: title, title: title),
            ],
          );
          await pumpAddon(
            tester,
            addon,
            queryParams: {'analytics': '{enabled:true}'},
          );
          await rescan(tester);
          expect(find.text('first'), findsOneWidget);

          titles = ['second'];
          refresh.notifyListeners();
          await tester.pump();
          await tester.pump();

          expect(find.text('second'), findsOneWidget);
        },
      );

      testWidgets(
        'given nothing changes, '
        'then rescans do not schedule frames',
        (tester) async {
          await pumpAddon(
            tester,
            addonWith(markers),
            queryParams: {'analytics': '{enabled:true}'},
          );
          await rescan(tester);

          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.binding.hasScheduledFrame, isFalse);
        },
      );

      Future<GlobalKey> pumpCrowded(WidgetTester tester) async {
        final rowKey = GlobalKey();
        final addon = AnalyticsAddon(
          resolve: (_) => [
            for (var i = 0; i < 16; i++)
              AnalyticsMarker(
                id: '$i',
                title: 'event $i',
                properties: const {'a': '1', 'b': '2'},
                target: rowKey.currentContext as Element?,
              ),
          ],
        );
        tester.view.physicalSize = const Size(1600, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidgetWithQueryParams(
          queryParams: {'analytics': '{enabled:true}'},
          builder: (context) => addon.buildUseCase(
            context,
            Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(key: rowKey, width: 200, height: 40),
            ),
            true,
          ),
        );
        await rescan(tester);
        return rowKey;
      }

      Rect cardOf(WidgetTester tester, int i) => tester.getRect(
        find
            .ancestor(
              of: find.text('event $i'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );

      Future<void> wheel(WidgetTester tester, Offset at, double dy) async {
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(at));
        await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
        await tester.pump();
      }

      testWidgets(
        'given more cards than fit, '
        'then both columns fill up and say how many cards are below',
        (tester) async {
          await pumpCrowded(tester);

          final cards = [for (var i = 0; i < 16; i++) cardOf(tester, i)];
          expect(cards.any((card) => card.left == 16), isTrue);
          expect(cards.any((card) => card.left > 800), isTrue);
          expect(find.textContaining('more'), findsWidgets);
        },
      );

      testWidgets(
        'when the wheel turns over an overflowing column, '
        'then that column scrolls to the cards below',
        (tester) async {
          await pumpCrowded(tester);
          final last = cardOf(tester, 15);
          final column = last.left == 16 ? 100.0 : 1500.0;

          await wheel(tester, Offset(column, 300), 10000);

          final scrolled = cardOf(tester, 15);
          expect(scrolled.top, lessThan(last.top));
          expect(
            scrolled.overlaps(tester.getRect(find.text('Analytics'))),
            isFalse,
          );
          expect(scrolled.bottom, lessThanOrEqualTo(700));
        },
      );

      testWidgets(
        'when the wheel turns over the middle, '
        'then the cards stay put',
        (tester) async {
          await pumpCrowded(tester);
          final before = cardOf(tester, 15);

          await wheel(tester, const Offset(800, 300), 10000);

          expect(cardOf(tester, 15), before);
        },
      );

      testWidgets(
        'when a "more" chip is tapped, '
        'then its column scrolls towards the hidden cards',
        (tester) async {
          await pumpCrowded(tester);
          final before = [for (var i = 0; i < 16; i++) cardOf(tester, i)];

          await tester.tap(find.textContaining('more').first);
          await tester.pump();

          final after = [for (var i = 0; i < 16; i++) cardOf(tester, i)];
          expect(after, isNot(before));
        },
      );

      testWidgets(
        'given cards whose targets are low on the screen, '
        'then they stack upwards and stay visible',
        (tester) async {
          final rowKey = GlobalKey();
          final addon = AnalyticsAddon(
            resolve: (_) => [
              for (var i = 0; i < 5; i++)
                AnalyticsMarker(
                  id: '$i',
                  title: 'event $i',
                  properties: const {'a': '1', 'b': '2'},
                  target: rowKey.currentContext as Element?,
                ),
            ],
          );
          tester.view.physicalSize = const Size(1600, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidgetWithQueryParams(
            queryParams: {'analytics': '{enabled:true}'},
            builder: (context) => addon.buildUseCase(
              context,
              Align(
                alignment: Alignment.bottomRight,
                child: SizedBox(key: rowKey, width: 200, height: 40),
              ),
              true,
            ),
          );
          await rescan(tester);

          final toggle = tester.getRect(find.text('Analytics'));
          for (var i = 0; i < 5; i++) {
            final card = cardOf(tester, i);
            expect(card.top, greaterThanOrEqualTo(16));
            expect(card.bottom, lessThanOrEqualTo(toggle.top));
          }
          expect(find.textContaining('more'), findsNothing);
        },
      );
    },
  );
}

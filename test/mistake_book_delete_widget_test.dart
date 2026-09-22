import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/screens/puzzle_screen.dart';
import 'package:chessnut_flutter_export/services/app_preferences_store.dart';
import 'package:chessnut_flutter_export/services/mistake_book_service.dart';

void main() {
  testWidgets('Windows Mistake Book deletes a saved mistake', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      final now = DateTime.now();
      const entryId = 'windows-delete-entry';
      final preferences = MemoryAppPreferencesStore(
        StoredAppPreferences(
          mistakeBook: MistakeBookState(
            entries: {
              entryId: MistakeBookEntry(
                id: entryId,
                reportKey: 'windows-delete-report',
                pgn: '[Event "Windows delete"]\n\n1. e4 *',
                sourceTitle: 'Windows Player vs Bot',
                ply: 1,
                moveSan: '1. e4?',
                bestMoveSan: 'd4',
                classification: 'Mistake',
                summary: 'Delete this saved mistake.',
                theme: 'Development',
                fenBefore: 'startpos',
                fenAfter: 'startpos',
                engineLine: 'd4 d5',
                createdAt: now,
                updatedAt: now,
                dueAt: now,
              ),
            },
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MistakeBookScreen(
              onNavigate: (_) {},
              store: AppPreferencesMistakeBookStore(preferences),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteButton =
          find.byKey(const ValueKey('mistake-delete-windows-delete-entry'));
      expect(deleteButton, findsOneWidget);
      expect(
        find.byKey(const ValueKey('mistake-list-entry-windows-delete-entry')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('mistake-list-entry-windows-delete-entry'),
          ),
          matching: find.byIcon(Icons.delete_outline_rounded),
        ),
        findsNothing,
      );
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      expect(find.text('Delete mistake?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleteButton, findsNothing);
      expect(
        (await AppPreferencesMistakeBookStore(preferences).read()).entries,
        isEmpty,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Windows Mistake Book batch deletes all entries across pages', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      final now = DateTime.now();
      final ids = [
        'batch-one',
        'batch-two',
        for (var index = 3; index <= 12; index++) 'batch-$index',
      ];
      final entries = <String, MistakeBookEntry>{
        for (final id in ids)
          id: MistakeBookEntry(
            id: id,
            reportKey: 'report-$id',
            pgn: '[Event "Windows batch"]\n\n1. e4 *',
            sourceTitle: 'Windows Player vs Bot',
            ply: 1,
            moveSan: '1. e4?',
            bestMoveSan: 'd4',
            classification: 'Mistake',
            summary: 'Batch delete this saved mistake.',
            theme: 'Development',
            fenBefore: 'startpos',
            fenAfter: 'startpos',
            engineLine: 'd4 d5',
            createdAt: now,
            updatedAt: now,
            dueAt: now,
            mastered: id == 'batch-two',
          ),
      };
      final preferences = MemoryAppPreferencesStore(
        StoredAppPreferences(mistakeBook: MistakeBookState(entries: entries)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MistakeBookScreen(
              onNavigate: (_) {},
              store: AppPreferencesMistakeBookStore(preferences),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('mistake-bulk-delete-start')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('mistake-bulk-select-batch-one')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey('mistake-bulk-select-batch-one')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('mistake-bulk-delete-confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('mistake-bulk-select-all')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey('mistake-bulk-select-batch-one')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey('mistake-bulk-select-batch-two')),
            )
            .value,
        isTrue,
      );
      await tester.tap(
        find.byKey(const ValueKey('mistake-bulk-delete-confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete 12 mistakes?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      final savedState =
          await AppPreferencesMistakeBookStore(preferences).read();
      expect(savedState.entries, isEmpty);
      expect(savedState.deletedIds, containsAll(ids));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Mistake Book deletion controls render on all app platforms', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    try {
      for (final configuration in [
        (
          name: 'android-phone',
          platform: TargetPlatform.android,
          size: const Size(390, 844),
          isClock: false,
        ),
        (
          name: 'chess-clock',
          platform: TargetPlatform.android,
          size: const Size(1024, 600),
          isClock: true,
        ),
        (
          name: 'ios-phone',
          platform: TargetPlatform.iOS,
          size: const Size(390, 844),
          isClock: false,
        ),
        (
          name: 'macos',
          platform: TargetPlatform.macOS,
          size: const Size(1440, 900),
          isClock: false,
        ),
      ]) {
        debugDefaultTargetPlatformOverride = configuration.platform;
        tester.view.physicalSize = configuration.size;
        final now = DateTime.now();
        const entryId = 'platform-entry';
        final preferences = MemoryAppPreferencesStore(
          StoredAppPreferences(
            mistakeBook: MistakeBookState(
              entries: {
                entryId: MistakeBookEntry(
                  id: entryId,
                  reportKey: 'platform-report',
                  pgn: '[Event "Platform delete"]\n\n1. e4 *',
                  sourceTitle: 'Player vs Bot',
                  ply: 1,
                  moveSan: '1. e4?',
                  bestMoveSan: 'd4',
                  classification: 'Mistake',
                  summary: 'Delete this mistake on every app platform.',
                  theme: 'Development',
                  fenBefore: 'startpos',
                  fenAfter: 'startpos',
                  engineLine: 'd4 d5',
                  createdAt: now,
                  updatedAt: now,
                  dueAt: now,
                ),
              },
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MistakeBookScreen(
                key: ValueKey(configuration.name),
                onNavigate: (_) {},
                store: AppPreferencesMistakeBookStore(preferences),
                isChessnutClockDevice: configuration.isClock,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${configuration.name}-initial',
        );

        final deleteButton =
            find.byKey(const ValueKey('mistake-delete-platform-entry'));
        if (deleteButton.evaluate().isEmpty) {
          final listEntry = find.byKey(
            const ValueKey('mistake-list-entry-platform-entry'),
          );
          await tester.ensureVisible(listEntry);
          await tester.pumpAndSettle();
          await tester.tap(listEntry);
          await tester.pumpAndSettle();
        }
        expect(deleteButton, findsOneWidget, reason: configuration.name);
        final bulkDeleteStart =
            find.byKey(const ValueKey('mistake-bulk-delete-start'));
        expect(bulkDeleteStart, findsOneWidget, reason: configuration.name);
        await tester.ensureVisible(bulkDeleteStart);
        await tester.pumpAndSettle();
        await tester.tap(bulkDeleteStart);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('mistake-bulk-select-platform-entry')),
          findsOneWidget,
          reason: configuration.name,
        );
        if (configuration.isClock) {
          expect(find.text('Delete (0)'), findsNothing);
          expect(find.text('Select all'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('mistake-bulk-select-all')),
            findsOneWidget,
          );
          expect(
            tester.widget(
              find.byKey(const ValueKey('mistake-bulk-select-all')),
            ),
            isA<InkWell>(),
          );
          expect(
            find.descendant(
              of: find.byKey(
                const ValueKey('mistake-bulk-delete-confirm'),
              ),
              matching: find.byIcon(Icons.delete_outline_rounded),
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull, reason: configuration.name);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });
}

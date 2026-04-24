import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/reader/domain/reader_page_analysis.dart';
import 'package:lectio/features/reader/presentation/controllers/reader_pdf_search_controller.dart';

void main() {
  group('ReaderPdfSearchController', () {
    late ReaderPdfSearchController controller;

    setUp(() {
      controller = ReaderPdfSearchController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('starts with expected defaults', () {
      expect(controller.results, isEmpty);
      expect(controller.activeResultIndex, -1);
      expect(controller.isVisible, isFalse);
      expect(controller.isSearching, isFalse);
      expect(controller.textController.text, isEmpty);
    });

    test('show and close update visibility and clear state', () {
      var cleared = false;
      controller.show();
      controller.textController.text = 'biology';

      controller.close(onCleared: () {
        cleared = true;
      });

      expect(controller.isVisible, isFalse);
      expect(controller.results, isEmpty);
      expect(controller.activeResultIndex, -1);
      expect(controller.isSearching, isFalse);
      expect(controller.textController.text, isEmpty);
      expect(cleared, isTrue);
    });

    test('runSearch clears short queries', () async {
      var cleared = false;
      controller.textController.text = 'a';

      await controller.runSearch(
        'a',
        search: (_) async => throw UnimplementedError(),
        openResult: (_, {updateSearchIndex = true}) async {},
        onCleared: () {
          cleared = true;
        },
      );

      expect(controller.results, isEmpty);
      expect(controller.activeResultIndex, -1);
      expect(controller.isSearching, isFalse);
      expect(cleared, isTrue);
    });

    test('runSearch stores results and opens first match', () async {
      final results = [
        const PdfSearchResult(
          pageNumber: 2,
          sentenceIndex: 1,
          query: 'cell',
          snippet: 'Cell membranes regulate transport.',
        ),
        const PdfSearchResult(
          pageNumber: 5,
          sentenceIndex: 0,
          query: 'cell',
          snippet: 'Cell theory explains structure.',
        ),
      ];
      PdfSearchResult? openedResult;
      bool? openedUpdateSearchIndex;

      controller.textController.text = 'cell';
      await controller.runSearch(
        'cell',
        search: (_) async => results,
        openResult: (result, {updateSearchIndex = true}) async {
          openedResult = result;
          openedUpdateSearchIndex = updateSearchIndex;
        },
      );

      expect(controller.results, results);
      expect(controller.activeResultIndex, 0);
      expect(controller.isSearching, isFalse);
      expect(openedResult, same(results.first));
      expect(openedUpdateSearchIndex, isFalse);
    });

    test('openPrevious and openNext rotate through results', () async {
      final results = [
        const PdfSearchResult(
          pageNumber: 1,
          sentenceIndex: 0,
          query: 'dna',
          snippet: 'DNA stores genetic information.',
        ),
        const PdfSearchResult(
          pageNumber: 2,
          sentenceIndex: 1,
          query: 'dna',
          snippet: 'DNA replicates before division.',
        ),
      ];
      final opened = <PdfSearchResult>[];

      controller.textController.text = 'dna';
      await controller.runSearch(
        'dna',
        search: (_) async => results,
        openResult: (result, {updateSearchIndex = true}) async {
          opened.add(result);
        },
      );

      await controller.openNext(
        openResult: (result, {updateSearchIndex = true}) async {
          opened.add(result);
        },
      );
      expect(controller.activeResultIndex, 1);

      await controller.openPrevious(
        openResult: (result, {updateSearchIndex = true}) async {
          opened.add(result);
        },
      );
      expect(controller.activeResultIndex, 0);
      expect(opened, containsAllInOrder([results.first, results.last, results.first]));
    });

    test('syncActiveResult updates active index when match exists', () async {
      final results = [
        const PdfSearchResult(
          pageNumber: 3,
          sentenceIndex: 0,
          query: 'atom',
          snippet: 'Atoms contain protons and neutrons.',
        ),
        const PdfSearchResult(
          pageNumber: 4,
          sentenceIndex: 2,
          query: 'atom',
          snippet: 'Atoms form molecules.',
        ),
      ];

      controller.textController.text = 'atom';
      await controller.runSearch(
        'atom',
        search: (_) async => results,
        openResult: (_, {updateSearchIndex = true}) async {},
      );

      controller.syncActiveResult(results.last);
      expect(controller.activeResultIndex, 1);
    });

    test('scheduleSearch debounces to the latest query', () async {
      final completer = Completer<void>();
      final seenQueries = <String>[];

      controller.textController.text = 'first';
      controller.scheduleSearch(
        'first',
        search: (query) async {
          seenQueries.add(query);
          return const [];
        },
        openResult: (_, {updateSearchIndex = true}) async {},
      );

      controller.textController.text = 'second';
      controller.scheduleSearch(
        'second',
        search: (query) async {
          seenQueries.add(query);
          completer.complete();
          return const [];
        },
        openResult: (_, {updateSearchIndex = true}) async {},
      );

      await completer.future.timeout(const Duration(seconds: 1));
      expect(seenQueries, ['second']);
    });
  });
}

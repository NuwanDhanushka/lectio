// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/app.dart';
import 'package:lectio/core/widgets/bottom_nav.dart';
import 'package:lectio/features/library/data/library_repository.dart';
import 'package:lectio/features/library/domain/library_item.dart';
import 'package:lectio/features/notebook/data/notebook_export_service.dart';
import 'package:lectio/features/notebook/domain/document_note.dart';
import 'package:lectio/features/notebook/presentation/document_notebook_sheet.dart';
import 'package:lectio/features/profile/presentation/widgets/profile_bookmark_activity.dart';
import 'package:lectio/features/reader/domain/document_bookmark.dart';
import 'package:lectio/features/reader/domain/reader_page_analysis.dart';
import 'package:lectio/features/reader/presentation/widgets/reader_outline.dart';
import 'package:lectio/features/tts/domain/tts_segmenter.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  test('canonicalizes legacy absolute library paths', () {
    expect(
      canonicalizeStoredLibraryPath(
        '/var/mobile/Containers/Data/Application/OLD-ID/Documents/library/1776644732962_AI_Engineering.pdf',
      ),
      'library/1776644732962_AI_Engineering.pdf',
    );
  });

  test('resolves stored relative library paths in the current documents dir',
      () {
    expect(
      resolveStoredLibraryPath(
        storedPath: 'library/1776644732962_AI_Engineering.pdf',
        documentsPath:
            '/var/mobile/Containers/Data/Application/NEW-ID/Documents',
      ),
      '/var/mobile/Containers/Data/Application/NEW-ID/Documents/library/1776644732962_AI_Engineering.pdf',
    );
  });

  test('prepares extracted pdf text for speech', () {
    expect(
      preparePdfPageTextForSpeech('Hello   world\n\nThis is a para-\n graph.'),
      'Hello world This is a paragraph.',
    );
  });

  test('splits speech text into readable sentence segments', () {
    expect(
      splitTextIntoSpeechSegments(
        'First sentence. Second question? Third exclamation!',
      ),
      ['First sentence.', 'Second question?', 'Third exclamation!'],
    );
  });

  test('keeps long speech text sentence-by-sentence', () {
    expect(
      splitTextIntoSpeechSegments(
        'This is a much longer sentence, with several phrases, that should be broken into smaller chunks for smoother tracking.',
      ),
      [
        'This is a much longer sentence, with several phrases, that should be broken into smaller chunks for smoother tracking.',
      ],
    );
  });

  test('extracts one speech segment for a long pdf sentence', () {
    const text =
        'This is a much longer sentence, with several phrases, that should be broken into smaller chunks for smoother tracking.';
    final pageText = PdfPageText(
      pageNumber: 1,
      fullText: text,
      charRects: List.generate(text.length, (_) => PdfRect.empty),
      fragments: const [],
    );

    final segments = extractSpeechSegmentsFromPageText(pageText);

    expect(
      segments.map((segment) => segment.text).toList(),
      [
        'This is a much longer sentence, with several phrases, that should be broken into smaller chunks for smoother tracking.',
      ],
    );
    expect(segments.first.range.start, 0);
    expect(segments.single.range.end, text.length);
  });

  test('keeps a heading separate from the following paragraph', () {
    const fullText =
        'Navigating This Book This book is structured to follow the typical process.';
    final pageText = PdfPageText(
      pageNumber: 1,
      fullText: fullText,
      charRects: List.generate(fullText.length, (_) => PdfRect.empty),
      fragments: [
        PdfPageTextFragment(
          pageText: PdfPageText(
            pageNumber: 1,
            fullText: fullText,
            charRects: List.generate(fullText.length, (_) => PdfRect.empty),
            fragments: const [],
          ),
          index: 0,
          length: 20,
          bounds: const PdfRect(0, 100, 120, 88),
          charRects: const [],
          direction: PdfTextDirection.ltr,
        ),
        PdfPageTextFragment(
          pageText: PdfPageText(
            pageNumber: 1,
            fullText: fullText,
            charRects: List.generate(fullText.length, (_) => PdfRect.empty),
            fragments: const [],
          ),
          index: 20,
          length: fullText.length - 20,
          bounds: const PdfRect(0, 80, 300, 68),
          charRects: const [],
          direction: PdfTextDirection.ltr,
        ),
      ],
    );

    final rebuiltPageText = PdfPageText(
      pageNumber: pageText.pageNumber,
      fullText: pageText.fullText,
      charRects: pageText.charRects,
      fragments: pageText.fragments
          .map(
            (fragment) => PdfPageTextFragment(
              pageText: pageText,
              index: fragment.index,
              length: fragment.length,
              bounds: fragment.bounds,
              charRects: fragment.charRects,
              direction: fragment.direction,
            ),
          )
          .toList(growable: false),
    );

    final segments = extractSpeechSegmentsFromPageText(rebuiltPageText);

    expect(segments.map((segment) => segment.text).toList(), [
      'Navigating This Book',
      'This book is structured to follow the typical process.',
    ]);
  });

  test('keeps bullet points as separate segments', () {
    const fullText =
        'Given a query, the quality depends on: • The instructions • The context • The model itself';
    final charRects = List.generate(fullText.length, (_) => PdfRect.empty);
    final basePageText = PdfPageText(
      pageNumber: 1,
      fullText: fullText,
      charRects: charRects,
      fragments: const [],
    );
    final pageText = PdfPageText(
      pageNumber: 1,
      fullText: fullText,
      charRects: charRects,
      fragments: [
        PdfPageTextFragment(
          pageText: basePageText,
          index: 0,
          length: fullText.length,
          bounds: const PdfRect(0, 100, 240, 88),
          charRects: const [],
          direction: PdfTextDirection.ltr,
        ),
      ],
    );

    final segments = extractSpeechSegmentsFromPageText(pageText);

    expect(segments.map((segment) => segment.text).toList(), [
      'Given a query, the quality depends on:',
      '• The instructions',
      '• The context',
      '• The model itself',
    ]);
  });

  test('converts reader page numbers into stored progress', () {
    expect(
      storedProgressForPage(pageNumber: 1, pageCount: 10),
      0,
    );
    expect(
      storedProgressForPage(pageNumber: 6, pageCount: 10),
      closeTo(5 / 9, 0.0001),
    );
    expect(
      storedProgressForPage(pageNumber: 10, pageCount: 10),
      1,
    );
  });

  test('restores the nearest page from stored progress', () {
    expect(
      pageNumberForStoredProgress(progress: 0, pageCount: 10),
      1,
    );
    expect(
      pageNumberForStoredProgress(progress: 5 / 9, pageCount: 10),
      6,
    );
    expect(
      pageNumberForStoredProgress(progress: 1, pageCount: 10),
      10,
    );
  });

  test('stores and removes bookmarks in the in-memory repository', () async {
    final repository = InMemoryLibraryRepository(
      seedItems: const [
        LibraryItem(
          id: 1,
          title: 'Bookmarked PDF',
          fileName: 'bookmarked.pdf',
          filePath: '/tmp/bookmarked.pdf',
          format: 'PDF',
        ),
      ],
    );
    const item = LibraryItem(
      id: 1,
      title: 'Bookmarked PDF',
      fileName: 'bookmarked.pdf',
      filePath: '/tmp/bookmarked.pdf',
      format: 'PDF',
    );

    final bookmark = await repository.addBookmark(
      item: item,
      pageNumber: 12,
    );
    final fetched = await repository.fetchBookmarks(item);

    expect(bookmark, isNotNull);
    expect(fetched, hasLength(1));
    expect(fetched.single.pageNumber, 12);

    await repository.removeBookmark(bookmark!);
    expect(await repository.fetchBookmarks(item), isEmpty);
  });

  test('stores and updates bookmark labels in the in-memory repository',
      () async {
    final repository = InMemoryLibraryRepository(
      seedItems: const [
        LibraryItem(
          id: 1,
          title: 'Label PDF',
          fileName: 'label.pdf',
          filePath: '/tmp/label.pdf',
          format: 'PDF',
        ),
      ],
    );
    const item = LibraryItem(
      id: 1,
      title: 'Label PDF',
      fileName: 'label.pdf',
      filePath: '/tmp/label.pdf',
      format: 'PDF',
    );

    final bookmark = await repository.addBookmark(
      item: item,
      pageNumber: 5,
      label: 'Important section',
    );
    final updated = await repository.updateBookmark(
      bookmark: bookmark!,
      label: 'Revisit later',
      note: '',
    );

    expect(bookmark.label, 'Important section');
    expect(updated, isNotNull);
    expect(updated!.label, 'Revisit later');
    expect(
        (await repository.fetchBookmarks(item)).single.label, 'Revisit later');
  });

  test('stores sentence bookmark notes in the in-memory repository', () async {
    final repository = InMemoryLibraryRepository(
      seedItems: const [
        LibraryItem(
          id: 1,
          title: 'Notes PDF',
          fileName: 'notes.pdf',
          filePath: '/tmp/notes.pdf',
          format: 'PDF',
        ),
      ],
    );
    const item = LibraryItem(
      id: 1,
      title: 'Notes PDF',
      fileName: 'notes.pdf',
      filePath: '/tmp/notes.pdf',
      format: 'PDF',
    );

    final bookmark = await repository.addBookmark(
      item: item,
      pageNumber: 7,
      sentenceIndex: 2,
      sentenceText: 'Important sentence.',
      label: 'Key idea',
      note: 'Use this in the summary.',
    );

    expect(bookmark, isNotNull);
    expect(bookmark!.sentenceIndex, 2);
    expect(bookmark.sentenceText, 'Important sentence.');
    expect(bookmark.note, 'Use this in the summary.');
  });

  test('stores, updates, and removes page summaries in memory', () async {
    final repository = InMemoryLibraryRepository(
      seedItems: const [
        LibraryItem(
          id: 1,
          title: 'Summary PDF',
          fileName: 'summary.pdf',
          filePath: '/tmp/summary.pdf',
          format: 'PDF',
        ),
      ],
    );
    const item = LibraryItem(
      id: 1,
      title: 'Summary PDF',
      fileName: 'summary.pdf',
      filePath: '/tmp/summary.pdf',
      format: 'PDF',
    );

    final saved = await repository.savePageSummary(
      item: item,
      pageNumber: 3,
      summary: 'First summary.',
    );
    final updated = await repository.savePageSummary(
      item: item,
      pageNumber: 3,
      summary: 'Updated summary.',
    );

    expect(saved, isNotNull);
    expect(updated, isNotNull);
    expect(updated!.id, saved!.id);
    expect(
      (await repository.fetchPageSummary(item: item, pageNumber: 3))!.summary,
      'Updated summary.',
    );

    await repository.removePageSummary(item: item, pageNumber: 3);
    expect(
      await repository.fetchPageSummary(item: item, pageNumber: 3),
      isNull,
    );
  });

  test('stores document notebook notes with source context', () async {
    final repository = InMemoryLibraryRepository(
      seedItems: const [
        LibraryItem(
          id: 1,
          title: 'Notebook PDF',
          fileName: 'notebook.pdf',
          filePath: '/tmp/notebook.pdf',
          format: 'PDF',
        ),
      ],
    );
    const item = LibraryItem(
      id: 1,
      title: 'Notebook PDF',
      fileName: 'notebook.pdf',
      filePath: '/tmp/notebook.pdf',
      format: 'PDF',
    );

    final note = await repository.addDocumentNote(
      item: item,
      kind: DocumentNoteKind.explanation,
      pageNumber: 12,
      sentenceIndex: 2,
      sentenceText: 'A hard sentence.',
      outlineTitle: 'Chapter 1',
      title: 'Explanation',
      body: 'This means the idea is important.',
    );
    final notes = await repository.fetchDocumentNotes(item);

    expect(note, isNotNull);
    expect(notes, hasLength(1));
    expect(notes.single.kind, DocumentNoteKind.explanation);
    expect(notes.single.pageNumber, 12);
    expect(notes.single.sentenceIndex, 2);
    expect(notes.single.outlineTitle, 'Chapter 1');
    expect(notes.single.body, 'This means the idea is important.');

    await repository.removeDocumentNote(notes.single);
    expect(await repository.fetchDocumentNotes(item), isEmpty);
  });

  test('builds notebook snapshots from documents with notes', () async {
    final repository = InMemoryLibraryRepository(
      seedItems: const [
        LibraryItem(
          id: 1,
          title: 'Notebook A',
          fileName: 'a.pdf',
          filePath: '/tmp/a.pdf',
          format: 'PDF',
        ),
        LibraryItem(
          id: 2,
          title: 'Notebook B',
          fileName: 'b.pdf',
          filePath: '/tmp/b.pdf',
          format: 'PDF',
        ),
      ],
    );
    const first = LibraryItem(
      id: 1,
      title: 'Notebook A',
      fileName: 'a.pdf',
      filePath: '/tmp/a.pdf',
      format: 'PDF',
    );
    const second = LibraryItem(
      id: 2,
      title: 'Notebook B',
      fileName: 'b.pdf',
      filePath: '/tmp/b.pdf',
      format: 'PDF',
    );

    await repository.addDocumentNote(
      item: first,
      kind: DocumentNoteKind.summary,
      pageNumber: 1,
      body: 'First note.',
    );
    await repository.addDocumentNote(
      item: second,
      kind: DocumentNoteKind.explanation,
      pageNumber: 2,
      body: 'Second note.',
    );

    final snapshots = await repository.fetchNotebookSnapshot();

    expect(snapshots, hasLength(2));
    expect(snapshots.first.item.title, 'Notebook A');
    expect(snapshots.first.notes.single.body, 'First note.');
    expect(snapshots.last.item.title, 'Notebook B');
  });

  test('formats document notes for clipboard copy', () {
    final text = documentNoteClipboardText(
      DocumentNote(
        documentId: 1,
        kind: DocumentNoteKind.explanation,
        pageNumber: 12,
        sentenceText: 'A hard sentence.',
        outlineTitle: 'Chapter 1',
        body: 'This means the idea is important.',
        createdAt: DateTime(2026),
      ),
    );

    expect(text, contains('Explanation'));
    expect(text, contains('Page 12'));
    expect(text, contains('Chapter 1'));
    expect(text, contains('A hard sentence.'));
    expect(text, contains('This means the idea is important.'));
  });

  test('groups document notes by outline title', () {
    final notes = [
      DocumentNote(
        documentId: 1,
        kind: DocumentNoteKind.summary,
        pageNumber: 2,
        outlineTitle: 'Chapter 1',
        body: 'Summary',
        createdAt: DateTime(2026),
      ),
      DocumentNote(
        documentId: 1,
        kind: DocumentNoteKind.explanation,
        pageNumber: 3,
        outlineTitle: 'Chapter 1',
        body: 'Explanation',
        createdAt: DateTime(2026),
      ),
      DocumentNote(
        documentId: 1,
        kind: DocumentNoteKind.summary,
        pageNumber: 4,
        body: 'No section',
        createdAt: DateTime(2026),
      ),
    ];
    final groups = groupedDocumentNotes(notes);

    expect(groups, hasLength(2));
    expect(groups.first.title, 'Chapter 1');
    expect(groups.first.notes, hasLength(2));
    expect(groups.last.title, 'Unsectioned Notes');
    expect(
      filterDocumentNotes(notes, DocumentNoteKind.explanation),
      hasLength(1),
    );
    expect(filterDocumentNotes(notes, null), hasLength(3));
  });

  test('prefixes selected notebook export notes with document titles', () {
    const item = LibraryItem(
      id: 1,
      title: 'AI Engineering',
      fileName: 'ai.pdf',
      filePath: '/tmp/ai.pdf',
      format: 'PDF',
    );
    final notes = notesForSelectedNotebookExport([
      DocumentNotebookSnapshotEntry(
        item: item,
        notes: [
          DocumentNote(
            documentId: 1,
            kind: DocumentNoteKind.summary,
            pageNumber: 2,
            outlineTitle: 'Chapter 1',
            body: 'Summary.',
            createdAt: DateTime(2026),
          ),
        ],
      ),
    ]);

    expect(notes.single.outlineTitle, 'AI Engineering / Chapter 1');
  });

  test('builds notebook pdf export data', () async {
    const item = LibraryItem(
      id: 1,
      title: 'AI Engineering',
      fileName: 'ai.pdf',
      filePath: '/tmp/ai.pdf',
      format: 'PDF',
    );
    final notes = [
      DocumentNote(
        documentId: 1,
        kind: DocumentNoteKind.summary,
        pageNumber: 2,
        outlineTitle: 'Chapter 1',
        body: 'Summary',
        createdAt: DateTime(2026),
      ),
    ];

    final bytes = await buildNotebookPdf(item: item, notes: notes);
    final groups = groupedNotesForExport(notes);

    expect(bytes, isNotEmpty);
    expect(groups.single.title, 'Chapter 1');
    expect(notebookPdfFileName(item), 'AI_Engineering_Notebook.pdf');
  });

  test('builds notebook docx export data', () {
    const item = LibraryItem(
      id: 1,
      title: 'AI Engineering',
      fileName: 'ai.pdf',
      filePath: '/tmp/ai.pdf',
      format: 'PDF',
    );
    final notes = [
      DocumentNote(
        documentId: 1,
        kind: DocumentNoteKind.explanation,
        pageNumber: 4,
        sentenceIndex: 1,
        sentenceText: 'Tokens split words into useful pieces.',
        outlineTitle: 'Tokenization',
        body: 'The model uses tokens instead of raw characters.',
        createdAt: DateTime(2026),
      ),
    ];

    final bytes = buildNotebookDocx(item: item, notes: notes);
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXml = utf8.decode(
      archive.findFile('word/document.xml')!.readBytes()!,
    );

    expect(bytes, isNotEmpty);
    expect(archive.findFile('[Content_Types].xml'), isNotNull);
    expect(documentXml, contains('Tokenization'));
    expect(documentXml, contains('Tokens split words into useful pieces.'));
    expect(notebookDocxFileName(item), 'AI_Engineering_Notebook.docx');
  });

  test('builds bookmark snapshot entries from the in-memory repository',
      () async {
    final repository = InMemoryLibraryRepository(
      seedItems: const [
        LibraryItem(
          id: 1,
          title: 'Snapshot PDF',
          fileName: 'snapshot.pdf',
          filePath: '/tmp/snapshot.pdf',
          format: 'PDF',
        ),
      ],
    );
    const item = LibraryItem(
      id: 1,
      title: 'Snapshot PDF',
      fileName: 'snapshot.pdf',
      filePath: '/tmp/snapshot.pdf',
      format: 'PDF',
    );

    await repository.addBookmark(item: item, pageNumber: 9);
    final snapshot = await repository.fetchBookmarkSnapshot();

    expect(snapshot, hasLength(1));
    expect(snapshot.single.item.title, 'Snapshot PDF');
    expect(snapshot.single.bookmark.pageNumber, 9);
  });

  test('exports bookmarks as markdown grouped by document', () {
    const item = LibraryItem(
      id: 1,
      title: 'Export PDF',
      fileName: 'export.pdf',
      filePath: '/tmp/export.pdf',
      format: 'PDF',
    );
    final markdown = exportBookmarksAsMarkdown([
      BookmarkSnapshotEntry(
        item: item,
        bookmark: DocumentBookmark(
          id: 1,
          documentId: 1,
          pageNumber: 8,
          sentenceIndex: 1,
          sentenceText: 'This is the saved passage.',
          label: 'Useful quote',
          note: 'Remember this for the report.',
          createdAt: DateTime(2026),
        ),
      ),
    ]);

    expect(markdown, contains('# Lectio Bookmarks'));
    expect(markdown, contains('## Export PDF'));
    expect(markdown, contains('### Useful quote'));
    expect(markdown, contains('Page: 8, sentence 2'));
    expect(markdown, contains('> This is the saved passage.'));
    expect(markdown, contains('Remember this for the report.'));
  });

  test('groups bookmark snapshot entries by document', () {
    const firstItem = LibraryItem(
      id: 1,
      title: 'First PDF',
      fileName: 'first.pdf',
      filePath: '/tmp/first.pdf',
      format: 'PDF',
    );
    const secondItem = LibraryItem(
      id: 2,
      title: 'Second PDF',
      fileName: 'second.pdf',
      filePath: '/tmp/second.pdf',
      format: 'PDF',
    );
    final entries = [
      BookmarkSnapshotEntry(
        item: firstItem,
        bookmark: DocumentBookmark(
          id: 1,
          documentId: 1,
          pageNumber: 2,
          createdAt: DateTime(2026),
        ),
      ),
      BookmarkSnapshotEntry(
        item: firstItem,
        bookmark: DocumentBookmark(
          id: 2,
          documentId: 1,
          pageNumber: 4,
          createdAt: DateTime(2026),
        ),
      ),
      BookmarkSnapshotEntry(
        item: secondItem,
        bookmark: DocumentBookmark(
          id: 3,
          documentId: 2,
          pageNumber: 6,
          createdAt: DateTime(2026),
        ),
      ),
    ];

    final groups = groupBookmarksByDocument(entries);

    expect(groups, hasLength(2));
    expect(groups.first.item.title, 'First PDF');
    expect(groups.first.entries, hasLength(2));
    expect(groups.last.item.title, 'Second PDF');
    expect(groups.last.entries, hasLength(1));
  });

  testWidgets('Bottom nav can render hidden', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNav(
            selectedIndex: 1,
            isVisible: false,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navSize = tester.getSize(find.byType(BottomNav));
    expect(navSize.height, 0);
  });

  test('computes an in-sentence karaoke progress range', () {
    final pageText = PdfPageText(
      pageNumber: 1,
      fullText: 'Hello world.',
      charRects: List.generate(12, (_) => PdfRect.empty),
      fragments: const [],
    );
    final fullRange = PdfPageTextRange(pageText: pageText, start: 0, end: 12);

    final progressRange = activeSpokenProgressRangeForPage(
      pageNumber: 1,
      spokenRangesPageNumber: 1,
      spokenSentenceRanges: [fullRange],
      currentUtteranceIndex: 0,
      currentUtteranceProgress: 0.5,
    );

    expect(progressRange, isNotNull);
    expect(progressRange!.start, 0);
    expect(progressRange.end, 6);
  });

  test('weights whitespace lightly for karaoke progress', () {
    expect(
      spokenCharacterLengthForProgress(
        text: 'ab   cd',
        progress: 0.5,
      ),
      2,
    );
  });

  test('tracks partial progress inside the active spoken character', () {
    final marker = karaokeProgressMarkerForText(
      text: 'Hello world.',
      progress: 0.5,
    );

    expect(marker.spokenLength, 6);
    expect(marker.partialCharacterProgress, greaterThan(0));
    expect(marker.partialCharacterProgress, lessThan(1));
  });

  test('holds at word boundaries through spaces and punctuation', () {
    final marker = karaokeProgressMarkerForText(
      text: 'Hello,   world.',
      progress: 0.49,
    );

    expect(marker.spokenLength, 5);
    expect(marker.partialCharacterProgress, 0);
  });

  test('uses word-aware timing for long lines', () {
    final marker = karaokeProgressMarkerForText(
      text: 'Short extraordinarilylongword ending.',
      progress: 0.55,
    );

    expect(marker.spokenLength, greaterThan(6));
    expect(marker.spokenLength, lessThan(30));
    expect(marker.partialCharacterProgress, greaterThanOrEqualTo(0));
    expect(marker.partialCharacterProgress, lessThan(1));
  });

  test('merges nearby character rects into a single highlight block', () {
    const pageText = PdfPageText(
      pageNumber: 1,
      fullText: 'abc',
      charRects: [
        PdfRect(0, 10, 4, 0),
        PdfRect(4.2, 10, 8, 0),
        PdfRect(8.4, 10, 12, 0),
      ],
      fragments: [],
    );
    const range = PdfPageTextRange(pageText: pageText, start: 0, end: 3);

    final merged = mergedHighlightRectsForRange(range);

    expect(merged, hasLength(1));
    expect(merged.first.left, 0);
    expect(merged.first.right, 12);
  });

  test('computes a bounding rect for the active text range', () {
    const pageText = PdfPageText(
      pageNumber: 1,
      fullText: 'abcd',
      charRects: [
        PdfRect(0, 20, 4, 10),
        PdfRect(4.2, 20, 8, 10),
        PdfRect(0, 8, 4, 0),
        PdfRect(4.2, 8, 8, 0),
      ],
      fragments: [],
    );
    const range = PdfPageTextRange(pageText: pageText, start: 0, end: 4);

    final boundingRect = boundingPdfRectForRange(range);

    expect(boundingRect, isNotNull);
    expect(boundingRect!.left, 0);
    expect(boundingRect.right, 8);
    expect(boundingRect.top, 20);
    expect(boundingRect.bottom, 0);
  });

  test('finds the tapped sentence by document position', () {
    final index = sentenceIndexForDocumentPositionFromRects(
      documentPosition: const Offset(30, 15),
      rects: const [
        Rect.fromLTWH(0, 0, 20, 20),
        Rect.fromLTWH(24, 0, 20, 20),
        Rect.fromLTWH(48, 0, 20, 20),
      ],
    );

    expect(index, 1);
  });

  test('falls back to the nearest sentence when tap misses exact bounds', () {
    final index = sentenceIndexForDocumentPositionFromRects(
      documentPosition: const Offset(46, 12),
      rects: const [
        Rect.fromLTWH(0, 0, 20, 20),
        Rect.fromLTWH(24, 0, 20, 20),
        Rect.fromLTWH(80, 0, 20, 20),
      ],
    );

    expect(index, 1);
  });

  test('builds a partial highlight rect for the current character', () {
    const pageText = PdfPageText(
      pageNumber: 1,
      fullText: 'ab',
      charRects: [
        PdfRect(0, 10, 4, 0),
        PdfRect(4, 10, 10, 0),
      ],
      fragments: [],
    );
    const range = PdfPageTextRange(pageText: pageText, start: 0, end: 2);

    final partialRect = partialHighlightRectForRange(
      range: range,
      marker: const KaraokeProgressMarker(
        spokenLength: 1,
        partialCharacterProgress: 0.5,
      ),
    );

    expect(partialRect, isNotNull);
    expect(partialRect!.left, 4);
    expect(partialRect.right, 7);
  });

  test('searches speech segments on a page', () {
    final pageText = PdfPageText(
      pageNumber: 4,
      fullText: 'Alpha idea. Beta concept.',
      charRects: List.generate(25, (_) => PdfRect.empty),
      fragments: const [],
    );
    final segments = [
      PdfSpeechSegment(
        text: 'Alpha idea.',
        range: PdfPageTextRange(pageText: pageText, start: 0, end: 11),
      ),
      PdfSpeechSegment(
        text: 'Beta concept.',
        range: PdfPageTextRange(pageText: pageText, start: 12, end: 25),
      ),
    ];

    final results = searchSpeechSegmentsOnPage(
      pageNumber: 4,
      segments: segments,
      query: 'concept',
    );

    expect(results, hasLength(1));
    expect(results.single.pageNumber, 4);
    expect(results.single.sentenceIndex, 1);
    expect(results.single.query, 'concept');
    expect(results.single.snippet, 'Beta concept.');
  });

  test('finds the exact search match range inside a segment', () {
    final pageText = PdfPageText(
      pageNumber: 4,
      fullText: 'Alpha idea. Beta concept.',
      charRects: List.generate(25, (_) => PdfRect.empty),
      fragments: const [],
    );
    final segment = PdfSpeechSegment(
      text: 'Beta concept.',
      range: PdfPageTextRange(pageText: pageText, start: 12, end: 25),
    );

    final range = searchMatchRangeForSegment(
      segment: segment,
      query: 'concept',
    );

    expect(range, isNotNull);
    expect(range!.start, 17);
    expect(range.end, 24);
  });

  test('flattens pdf outline nodes with nesting levels', () {
    final entries = flattenPdfOutlineNodes(
      const [
        PdfOutlineNode(
          title: 'Chapter 1',
          dest: PdfDest(3, PdfDestCommand.fit, null),
          children: [
            PdfOutlineNode(
              title: 'Section 1.1',
              dest: PdfDest(4, PdfDestCommand.fit, null),
              children: [],
            ),
          ],
        ),
      ],
    );

    expect(entries, hasLength(2));
    expect(entries.first.title, 'Chapter 1');
    expect(entries.first.pageNumber, 3);
    expect(entries.first.level, 0);
    expect(entries.last.title, 'Section 1.1');
    expect(entries.last.pageNumber, 4);
    expect(entries.last.level, 1);
  });

  testWidgets('Home screen renders key sections', (WidgetTester tester) async {
    await tester.pumpWidget(
      LectioApp(
        repository: InMemoryLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lectio'), findsOneWidget);
    expect(find.text('Recently Accessed'), findsOneWidget);
    expect(find.text('Import New Document'), findsOneWidget);
    expect(find.text('LIBRARY'), findsWidgets);
  });

  testWidgets('Home screen shows continue reading for in-progress document', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      LectioApp(
        repository: InMemoryLibraryRepository(
          seedItems: const [
            LibraryItem(
              title: 'In Progress PDF',
              fileName: 'progress.pdf',
              filePath: '/missing/progress.pdf',
              format: 'PDF',
              progress: 0.42,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue Reading'), findsOneWidget);
    expect(find.text('In Progress PDF'), findsAtLeastNWidgets(1));
  });

  testWidgets('Bottom nav switches pages', (WidgetTester tester) async {
    await tester.pumpWidget(
      LectioApp(
        repository: InMemoryLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('READING'));
    await tester.pumpAndSettle();
    expect(
      find.text('Select a PDF from your library to start reading.'),
      findsOneWidget,
    );

    await tester.tap(find.text('ACTIVITY'));
    await tester.pumpAndSettle();
    expect(find.text('Activity'), findsOneWidget);

    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    expect(find.text('Voice Settings'), findsOneWidget);
  });

  testWidgets('Activity shows per-document bookmark actions', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryLibraryRepository(
      seedItems: const [
        LibraryItem(
          id: 1,
          title: 'Action PDF',
          fileName: 'action.pdf',
          filePath: '/missing/action.pdf',
          format: 'PDF',
        ),
      ],
    );
    const item = LibraryItem(
      id: 1,
      title: 'Action PDF',
      fileName: 'action.pdf',
      filePath: '/missing/action.pdf',
      format: 'PDF',
    );
    await repository.addBookmark(item: item, pageNumber: 4);
    await repository.addDocumentNote(
      item: item,
      kind: DocumentNoteKind.summary,
      pageNumber: 4,
      outlineTitle: 'Chapter 1',
      body: 'Notebook summary.',
    );

    await tester.pumpWidget(LectioApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ACTIVITY'));
    await tester.pumpAndSettle();

    expect(find.text('Action PDF'), findsAtLeastNWidgets(1));
    expect(find.byTooltip('Open first bookmark'), findsOneWidget);
    expect(find.byTooltip('Export this document'), findsOneWidget);
    expect(find.byTooltip('Export notebook'), findsOneWidget);
    expect(find.byTooltip('Collapse document'), findsOneWidget);
    expect(find.text('Notebooks'), findsOneWidget);

    await tester.tap(find.byTooltip('Export notebook'));
    await tester.pumpAndSettle();

    expect(find.text('Notebook PDF'), findsOneWidget);
    expect(find.text('Notebook DOCX'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Export notebooks'), findsOneWidget);
    expect(find.text('1 of 1 selected'), findsOneWidget);
    expect(find.text('Unselect all'), findsOneWidget);
  });

  testWidgets('Tapping a recent PDF opens the reader screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      LectioApp(
        repository: InMemoryLibraryRepository(
          seedItems: const [
            LibraryItem(
              title: 'Sample PDF',
              fileName: 'sample.pdf',
              filePath: '/missing/sample.pdf',
              format: 'PDF',
              progress: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sample PDF'));
    await tester.pumpAndSettle();

    expect(find.text('PDF not found'), findsOneWidget);
    expect(find.text('Page 1 / 0'), findsNothing);
    expect(find.text('Sample PDF - sample.pdf'), findsOneWidget);
    expect(find.text('READING'), findsOneWidget);
  });

  testWidgets('Recent item can be removed from the library list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      LectioApp(
        repository: InMemoryLibraryRepository(
          seedItems: const [
            LibraryItem(
              title: 'Disposable PDF',
              fileName: 'disposable.pdf',
              filePath: '/missing/disposable.pdf',
              format: 'PDF',
              progress: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Disposable PDF'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from recent'));
    await tester.pumpAndSettle();

    expect(find.text('Disposable PDF'), findsNothing);
    expect(find.text('Your library is empty'), findsOneWidget);
  });
}

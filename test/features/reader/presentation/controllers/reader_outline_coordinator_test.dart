import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/reader/presentation/controllers/reader_outline_coordinator.dart';
import 'package:pdfrx/pdfrx.dart';

class _FakePdfDest implements PdfDest {
  _FakePdfDest(this.pageNumber);

  @override
  final int pageNumber;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePdfOutlineNode implements PdfOutlineNode {
  _FakePdfOutlineNode({
    required this.title,
    required this.dest,
  });

  @override
  final String title;

  @override
  final PdfDest? dest;

  @override
  List<PdfOutlineNode> get children => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePdfDocument implements PdfDocument {
  _FakePdfDocument(this.outline);

  final List<PdfOutlineNode> outline;
  int loadOutlineCalls = 0;

  @override
  Future<List<PdfOutlineNode>> loadOutline() async {
    loadOutlineCalls++;
    return outline;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ReaderOutlineCoordinator', () {
    late ReaderOutlineCoordinator coordinator;

    setUp(() {
      coordinator = ReaderOutlineCoordinator();
    });

    test('loadOutlineEntries returns empty list for null document', () async {
      final result = await coordinator.loadOutlineEntries(
        document: null,
        pageCount: 10,
      );

      expect(result, isEmpty);
      expect(coordinator.cachedOutlineEntries, isNull);
    });

    test('loadOutlineEntries caches built-in outline entries', () async {
      final document = _FakePdfDocument([
        _FakePdfOutlineNode(
          title: 'Chapter 1',
          dest: _FakePdfDest(3),
        ),
        _FakePdfOutlineNode(
          title: 'Chapter 2',
          dest: _FakePdfDest(7),
        ),
      ]);

      final first = await coordinator.loadOutlineEntries(
        document: document,
        pageCount: 12,
      );
      final second = await coordinator.loadOutlineEntries(
        document: document,
        pageCount: 12,
      );

      expect(first, hasLength(2));
      expect(first.first.title, 'Chapter 1');
      expect(first.last.pageNumber, 7);
      expect(second, same(first));
      expect(document.loadOutlineCalls, 1);
      expect(coordinator.cachedOutlineEntries, same(first));
    });

    test('outlineTitleForPage returns nearest matching outline title',
        () async {
      final document = _FakePdfDocument([
        _FakePdfOutlineNode(
          title: 'Intro',
          dest: _FakePdfDest(1),
        ),
        _FakePdfOutlineNode(
          title: 'Methods',
          dest: _FakePdfDest(5),
        ),
        _FakePdfOutlineNode(
          title: 'Results',
          dest: _FakePdfDest(9),
        ),
      ]);

      final title = await coordinator.outlineTitleForPage(
        pageNumber: 6,
        document: document,
        pageCount: 12,
      );

      expect(title, 'Methods');
    });

    test('reset clears cached entries', () async {
      final document = _FakePdfDocument([
        _FakePdfOutlineNode(
          title: 'Overview',
          dest: _FakePdfDest(2),
        ),
      ]);

      await coordinator.loadOutlineEntries(
        document: document,
        pageCount: 8,
      );
      expect(coordinator.cachedOutlineEntries, isNotNull);

      coordinator.reset();

      expect(coordinator.cachedOutlineEntries, isNull);
    });
  });
}

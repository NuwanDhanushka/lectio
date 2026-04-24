import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../library/domain/library_item.dart';
import '../domain/document_note.dart';

class NotebookExportService {
  const NotebookExportService();

  Future<void> shareNotebookPdf({
    required LibraryItem item,
    required List<DocumentNote> notes,
  }) async {
    final bytes = await buildNotebookPdf(item: item, notes: notes);
    await Printing.sharePdf(
      bytes: bytes,
      filename: notebookPdfFileName(item),
    );
  }

  Future<void> shareNotebookDocx({
    required LibraryItem item,
    required List<DocumentNote> notes,
  }) async {
    final bytes = buildNotebookDocx(item: item, notes: notes);
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ),
      ],
      subject: '${item.title} Lectio Notebook',
      fileNameOverrides: [notebookDocxFileName(item)],
    );
  }
}

Future<Uint8List> buildNotebookPdf({
  required LibraryItem item,
  required List<DocumentNote> notes,
}) {
  final pdf = pw.Document();
  final groups = groupedNotesForExport(notes);
  final exportedAt = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());

  pdf.addPage(
    pw.MultiPage(
      pageTheme: const pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(40, 42, 40, 42),
      ),
      build: (context) => [
        pw.Text(
          item.title,
          style: pw.TextStyle(
            fontSize: 26,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#202430'),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Lectio Notebook • Exported $exportedAt',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColor.fromHex('#6F7585'),
          ),
        ),
        pw.SizedBox(height: 22),
        if (notes.isEmpty)
          pw.Text(
            'No notebook notes yet.',
            style: pw.TextStyle(
              fontSize: 13,
              color: PdfColor.fromHex('#4E5668'),
            ),
          )
        else
          for (final group in groups) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F4F6FF'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                group.title,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#355BE7'),
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            for (final note in group.notes) _buildNoteBlock(note),
            pw.SizedBox(height: 10),
          ],
      ],
    ),
  );

  return pdf.save();
}

Uint8List buildNotebookDocx({
  required LibraryItem item,
  required List<DocumentNote> notes,
}) {
  final archive = Archive();
  final documentXml = _buildDocxDocumentXml(item: item, notes: notes);
  final now = DateTime.now().toUtc().toIso8601String();

  void addFile(String path, String content) {
    archive.addFile(ArchiveFile.string(path, content));
  }

  addFile('[Content_Types].xml', _docxContentTypesXml);
  addFile('_rels/.rels', _docxRootRelsXml);
  addFile('docProps/app.xml', _docxAppXml);
  addFile('docProps/core.xml', _docxCoreXml(item.title, now));
  addFile('word/document.xml', documentXml);
  addFile('word/styles.xml', _docxStylesXml);

  return ZipEncoder().encodeBytes(archive);
}

String _buildDocxDocumentXml({
  required LibraryItem item,
  required List<DocumentNote> notes,
}) {
  final groups = groupedNotesForExport(notes);
  final exportedAt = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());
  final body = StringBuffer()
    ..write(_docxParagraph(item.title, style: 'Title'))
    ..write(_docxParagraph('Lectio Notebook - Exported $exportedAt',
        style: 'Subtitle'));

  if (notes.isEmpty) {
    body.write(_docxParagraph('No notebook notes yet.'));
  } else {
    for (final group in groups) {
      body.write(_docxParagraph(group.title, style: 'Heading1'));
      for (final note in group.notes) {
        body
          ..write(_docxParagraph(documentNoteKindExportLabel(note.kind),
              style: 'Heading2'))
          ..write(_docxParagraph(documentNoteReferenceExportLabel(note),
              style: 'Reference'));

        if (note.sentenceText.isNotEmpty) {
          body
            ..write(_docxParagraph('Source', style: 'Label'))
            ..write(_docxParagraph(note.sentenceText, style: 'Quote'));
        }

        body.write(_docxParagraph(note.body));
      }
    }
  }

  return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $body
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
''';
}

String _docxParagraph(String text, {String? style}) {
  final styleXml = style == null ? '' : '<w:pStyle w:val="$style"/>';
  final runs = LineSplitter.split(text).map((line) {
    return '<w:r><w:t xml:space="preserve">${_escapeXml(line)}</w:t></w:r>';
  }).join('<w:r><w:br/></w:r>');
  return '<w:p><w:pPr>$styleXml</w:pPr>$runs</w:p>';
}

String _escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

const _docxContentTypesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
''';

const _docxRootRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
''';

const _docxAppXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Lectio</Application>
</Properties>
''';

String _docxCoreXml(String title, String now) {
  final escapedTitle = _escapeXml(title);
  return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>$escapedTitle Lectio Notebook</dc:title>
  <dc:creator>Lectio</dc:creator>
  <cp:lastModifiedBy>Lectio</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>
</cp:coreProperties>
''';
}

const _docxStylesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr><w:sz w:val="22"/><w:color w:val="202430"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:rPr><w:b/><w:sz w:val="44"/><w:color w:val="202430"/></w:rPr>
    <w:pPr><w:spacing w:after="120"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Subtitle">
    <w:name w:val="Subtitle"/>
    <w:rPr><w:sz w:val="20"/><w:color w:val="6F7585"/></w:rPr>
    <w:pPr><w:spacing w:after="360"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="Heading 1"/>
    <w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="355BE7"/></w:rPr>
    <w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="Heading 2"/>
    <w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="202430"/></w:rPr>
    <w:pPr><w:spacing w:before="120" w:after="60"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Reference">
    <w:name w:val="Reference"/>
    <w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="5368E8"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Label">
    <w:name w:val="Label"/>
    <w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="7D8494"/></w:rPr>
    <w:pPr><w:spacing w:before="80" w:after="30"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Quote">
    <w:name w:val="Quote"/>
    <w:rPr><w:i/><w:sz w:val="20"/><w:color w:val="6F7585"/></w:rPr>
    <w:pPr><w:ind w:left="360"/><w:spacing w:after="120"/></w:pPr>
  </w:style>
</w:styles>
''';

pw.Widget _buildNoteBlock(DocumentNote note) {
  return pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColor.fromHex('#DCE2F0')),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                documentNoteKindExportLabel(note.kind),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#202430'),
                ),
              ),
            ),
            pw.Text(
              documentNoteReferenceExportLabel(note),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#5368E8'),
              ),
            ),
          ],
        ),
        if (note.sentenceText.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            'Source',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#7D8494'),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            note.sentenceText,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromHex('#6F7585'),
            ),
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Text(
          note.body,
          style: pw.TextStyle(
            fontSize: 11,
            lineSpacing: 2,
            color: PdfColor.fromHex('#202430'),
          ),
        ),
      ],
    ),
  );
}

class NotebookExportGroup {
  const NotebookExportGroup({
    required this.title,
    required this.notes,
  });

  final String title;
  final List<DocumentNote> notes;
}

List<NotebookExportGroup> groupedNotesForExport(List<DocumentNote> notes) {
  final groups = <String, List<DocumentNote>>{};
  for (final note in notes) {
    final title = note.outlineTitle.trim().isEmpty
        ? 'Unsectioned Notes'
        : note.outlineTitle;
    groups.putIfAbsent(title, () => []).add(note);
  }
  return groups.entries
      .map((entry) => NotebookExportGroup(title: entry.key, notes: entry.value))
      .toList(growable: false);
}

String documentNoteKindExportLabel(DocumentNoteKind kind) {
  return switch (kind) {
    DocumentNoteKind.summary => 'Summary',
    DocumentNoteKind.explanation => 'Explanation',
    DocumentNoteKind.question => 'Question',
  };
}

String documentNoteReferenceExportLabel(DocumentNote note) {
  final parts = <String>[
    'Page ${note.pageNumber}',
    if (note.sentenceIndex != null) 'Sentence ${note.sentenceIndex! + 1}',
  ];
  return parts.join(' • ');
}

String notebookPdfFileName(LibraryItem item) {
  return '${_safeNotebookFileName(item)}_Notebook.pdf';
}

String notebookDocxFileName(LibraryItem item) {
  return '${_safeNotebookFileName(item)}_Notebook.docx';
}

String _safeNotebookFileName(LibraryItem item) {
  final safeTitle = item.title
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return safeTitle.isEmpty ? 'Lectio' : safeTitle;
}

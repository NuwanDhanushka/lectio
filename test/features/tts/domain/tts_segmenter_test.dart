import 'package:flutter_test/flutter_test.dart';
import 'package:lectio/features/tts/domain/tts_segmenter.dart';

void main() {
  group('splitTextIntoSpeechSegments', () {
    test('returns empty list for blank text', () {
      expect(splitTextIntoSpeechSegments('   \n  '), isEmpty);
    });

    test('splits normalized text into sentence segments', () {
      expect(
        splitTextIntoSpeechSegments('Hello   world.  How are you?\nI am fine!'),
        ['Hello world.', 'How are you?', 'I am fine!'],
      );
    });
  });

  group('splitTextIntoSpeechChunks', () {
    test('keeps short sentences intact', () {
      expect(
        splitTextIntoSpeechChunks('One short sentence.'),
        ['One short sentence.'],
      );
    });

    test('splits long sentences into smaller natural chunks', () {
      const text =
          'This sentence has many words, enough to trigger chunking and create smaller readable pieces for speech playback.';

      final chunks = splitTextIntoSpeechChunks(text);

      expect(chunks.length, greaterThan(1));
      expect(chunks.join(' '), contains('trigger chunking'));
      expect(chunks.every((chunk) => chunk.trim().isNotEmpty), isTrue);
    });
  });
}

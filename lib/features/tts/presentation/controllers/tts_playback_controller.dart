import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class TtsPlaybackController extends ChangeNotifier {
  TtsPlaybackController();

  static const double karaokeProgressNotifyStep = 0.008;
  static const Duration karaokeNotifyInterval = Duration(milliseconds: 33);

  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<PlayerState>? _playerSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  VoidCallback? _onPlaybackCompleted;
  bool _initialized = false;
  int _playbackSessionId = 0;
  List<String> _queuedUtterances = const [];
  List<Duration> _queuedUtteranceEndTimes = const [];
  String _currentUtteranceText = '';
  int _currentUtteranceIndex = 0;
  int _utteranceCount = 0;
  double _currentUtteranceProgress = 0;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  double _lastNotifiedUtteranceProgress = 0;
  DateTime? _lastKaraokeNotifyAt;
  bool _isQueuePlaybackActive = false;
  bool _isPaused = false;

  String get currentUtteranceText => _currentUtteranceText;
  int get currentUtteranceIndex => _currentUtteranceIndex;
  int get utteranceCount => _utteranceCount;
  double get currentUtteranceProgress => _currentUtteranceProgress;
  Duration get playbackPosition => _playbackPosition;
  Duration get playbackDuration => _playbackDuration;
  bool get isQueuePlaybackActive => _isQueuePlaybackActive;
  bool get isPaused => _isPaused;
  double get playbackProgress => _playbackDuration.inMilliseconds <= 0
      ? 0
      : (_playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds)
          .clamp(0.0, 1.0);

  Future<void> ensureInitialized({
    required VoidCallback onPlaybackCompleted,
  }) async {
    _onPlaybackCompleted = onPlaybackCompleted;
    if (_initialized) {
      return;
    }

    _playerSubscription = _player.playerStateStream.listen((playerState) {
      if (_isPaused) {
        return;
      }

      if (playerState.processingState == ProcessingState.completed) {
        _isQueuePlaybackActive = false;
        _clearPlaybackProgress(notify: false);
        _onPlaybackCompleted?.call();
      }
    });
    _positionSubscription = _player.positionStream.listen((position) {
      if (!_isQueuePlaybackActive) {
        return;
      }

      _playbackPosition = position;

      if (_queuedUtteranceEndTimes.isEmpty) {
        notifyListeners();
        return;
      }

      var utteranceIndex = _queuedUtteranceEndTimes.length - 1;
      for (var i = 0; i < _queuedUtteranceEndTimes.length; i++) {
        if (position <= _queuedUtteranceEndTimes[i]) {
          utteranceIndex = i;
          break;
        }
      }

      final segmentStart = utteranceIndex == 0
          ? Duration.zero
          : _queuedUtteranceEndTimes[utteranceIndex - 1];
      final segmentEnd = _queuedUtteranceEndTimes[utteranceIndex];
      final segmentDurationMs =
          segmentEnd.inMilliseconds - segmentStart.inMilliseconds;
      final elapsedMs = position.inMilliseconds - segmentStart.inMilliseconds;
      final ratio =
          segmentDurationMs <= 0 ? 0.0 : elapsedMs / segmentDurationMs;
      final clampedRatio = ratio.clamp(0.0, 1.0);
      final utteranceChanged = _currentUtteranceIndex != utteranceIndex;
      final progressChangedEnough =
          (clampedRatio - _lastNotifiedUtteranceProgress).abs() >=
              karaokeProgressNotifyStep;
      final now = DateTime.now();
      final intervalElapsed = _lastKaraokeNotifyAt == null ||
          now.difference(_lastKaraokeNotifyAt!) >= karaokeNotifyInterval;

      _currentUtteranceIndex = utteranceIndex;
      _currentUtteranceText = _queuedUtterances[utteranceIndex];
      _currentUtteranceProgress = clampedRatio;

      if (utteranceChanged ||
          (progressChangedEnough && intervalElapsed) ||
          clampedRatio == 1.0) {
        _lastNotifiedUtteranceProgress = clampedRatio;
        _lastKaraokeNotifyAt = now;
        notifyListeners();
      }
    });

    _initialized = true;
  }

  Future<int> startSynthesisSession(List<String> utterances) async {
    await _player.stop();
    await _player.seek(Duration.zero, index: 0);
    final sessionId = ++_playbackSessionId;
    _isPaused = false;
    _isQueuePlaybackActive = true;
    _queuedUtterances = utterances;
    _utteranceCount = utterances.length;
    _currentUtteranceIndex = 0;
    _currentUtteranceText = utterances.first;
    _currentUtteranceProgress = 0;
    _lastNotifiedUtteranceProgress = 0;
    _lastKaraokeNotifyAt = null;
    _queuedUtteranceEndTimes = <Duration>[];
    _playbackPosition = Duration.zero;
    _playbackDuration = Duration.zero;
    notifyListeners();
    return sessionId;
  }

  bool isCurrentSession(int sessionId) => sessionId == _playbackSessionId;

  void updateQueuedUtteranceEndTimes(List<Duration> utteranceEndTimes) {
    _queuedUtteranceEndTimes = utteranceEndTimes;
  }

  Future<void> playFile({
    required String filePath,
    required List<Duration> utteranceEndTimes,
  }) async {
    _queuedUtteranceEndTimes = utteranceEndTimes;
    _playbackDuration = utteranceEndTimes.isEmpty
        ? (_player.duration ?? Duration.zero)
        : utteranceEndTimes.last;
    _playbackPosition = Duration.zero;
    _isPaused = false;
    await _player.setFilePath(filePath);
    _playbackDuration = utteranceEndTimes.isEmpty
        ? (_player.duration ?? Duration.zero)
        : utteranceEndTimes.last;
    await _player.play();
  }

  Future<void> stop() async {
    _playbackSessionId++;
    _isPaused = false;
    _isQueuePlaybackActive = false;
    await _player.stop();
    _clearPlaybackProgress(notify: true);
  }

  Future<void> pause() async {
    if (!_isQueuePlaybackActive) {
      return;
    }

    _isPaused = true;
    await _player.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    if (_currentUtteranceText.isEmpty) {
      return;
    }

    _isPaused = false;
    _isQueuePlaybackActive = true;
    await _player.play();
    notifyListeners();
  }

  Future<void> seekBy(Duration offset) async {
    if (!_isQueuePlaybackActive || _playbackDuration == Duration.zero) {
      return;
    }

    final target = _playbackPosition + offset;
    final clampedTarget = target < Duration.zero
        ? Duration.zero
        : target > _playbackDuration
            ? _playbackDuration
            : target;
    _playbackPosition = clampedTarget;
    await _player.seek(clampedTarget);
    notifyListeners();
  }

  Future<void> seekToUtteranceOffset(int offset) async {
    if (!_isQueuePlaybackActive || _queuedUtteranceEndTimes.isEmpty) {
      return;
    }

    final targetIndex = (_currentUtteranceIndex + offset)
        .clamp(0, _queuedUtteranceEndTimes.length - 1);
    final targetPosition = targetIndex == 0
        ? Duration.zero
        : _queuedUtteranceEndTimes[targetIndex - 1];

    _currentUtteranceIndex = targetIndex;
    _currentUtteranceText = _queuedUtterances[targetIndex];
    _currentUtteranceProgress = 0;
    _playbackPosition = targetPosition;
    await _player.seek(targetPosition);
    notifyListeners();
  }

  void _clearPlaybackProgress({bool notify = true}) {
    _queuedUtterances = const [];
    _queuedUtteranceEndTimes = const [];
    _currentUtteranceText = '';
    _currentUtteranceIndex = 0;
    _utteranceCount = 0;
    _currentUtteranceProgress = 0;
    _playbackPosition = Duration.zero;
    _playbackDuration = Duration.zero;
    _lastNotifiedUtteranceProgress = 0;
    _lastKaraokeNotifyAt = null;
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';

import '../../../tts/presentation/controllers/sherpa_tts_service.dart';

class ReaderTtsDock extends StatelessWidget {
  const ReaderTtsDock({
    super.key,
    required this.service,
    required this.isPreparingPlayback,
    required this.onPlayPressed,
    required this.onPausePressed,
    required this.onStopPressed,
    required this.onPreviousPressed,
    required this.onNextPressed,
  });

  final SherpaTtsService service;
  final bool isPreparingPlayback;
  final Future<void> Function() onPlayPressed;
  final Future<void> Function() onPausePressed;
  final Future<void> Function() onStopPressed;
  final Future<void> Function() onPreviousPressed;
  final Future<void> Function() onNextPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final canPlay =
            (service.isConfigured && !service.isBusy) || service.canResume;
        final canPause = service.status == SherpaTtsStatus.playing;
        final canStop = service.isBusy;
        final canSeek = service.playbackDuration > Duration.zero;
        final isPreparingSpeech = isPreparingPlayback ||
            service.status == SherpaTtsStatus.synthesizing;
        final elapsedLabel = service.playbackDuration > Duration.zero
            ? _formatPlaybackDuration(service.playbackPosition)
            : '--:--';
        final remaining = service.playbackDuration - service.playbackPosition;
        final remainingLabel = service.playbackDuration > Duration.zero
            ? '-${_formatPlaybackDuration(remaining.isNegative ? Duration.zero : remaining)}'
            : '--:--';
        final primaryIcon =
            canPause ? Icons.pause_rounded : Icons.play_arrow_rounded;
        final primaryAction = canPause
            ? onPausePressed
            : canPlay
                ? onPlayPressed
                : null;

        return Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFDCE2F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D141D3A),
                blurRadius: 26,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    elapsedLabel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFF555A66),
                    ),
                  ),
                  Text(
                    remainingLabel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFF555A66),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: service.playbackProgress,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE9ECF4),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF4C63F5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _PlaybackSpeedLabel(speed: service.config.speed),
                  _DockActionButton(
                    onPressed: canSeek ? onPreviousPressed : null,
                    icon: Icons.skip_previous_rounded,
                    tooltip: 'Previous sentence',
                  ),
                  _DockPrimaryButton(
                    onPressed: primaryAction,
                    icon: primaryIcon,
                    isLoading: isPreparingSpeech,
                    tooltip: canPause
                        ? 'Pause voice playback'
                        : 'Read current page aloud',
                  ),
                  _DockActionButton(
                    onPressed: canSeek ? onNextPressed : null,
                    icon: Icons.skip_next_rounded,
                    tooltip: 'Next sentence',
                  ),
                  _DockActionButton(
                    onPressed: canStop ? onStopPressed : null,
                    icon: Icons.stop_rounded,
                    tooltip: 'Stop voice playback',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlaybackSpeedLabel extends StatelessWidget {
  const _PlaybackSpeedLabel({required this.speed});

  final double speed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Text(
        '${speed.toStringAsFixed(2)}x',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: Color(0xFF555A66),
        ),
      ),
    );
  }
}

class _DockPrimaryButton extends StatelessWidget {
  const _DockPrimaryButton({
    required this.icon,
    required this.tooltip,
    this.isLoading = false,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isLoading;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final action = onPressed;

    return SizedBox(
      width: 60,
      height: 60,
      child: IconButton(
        onPressed: action == null ? null : () => action(),
        tooltip: tooltip,
        iconSize: 34,
        icon: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF4C63F5),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
          disabledBackgroundColor: const Color(0xFFB8C2F8),
          shadowColor: const Color(0x554C63F5),
          elevation: 10,
        ),
      ),
    );
  }
}

class _DockActionButton extends StatelessWidget {
  const _DockActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final action = onPressed;

    return IconButton(
      onPressed: action == null ? null : () => action(),
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFEFF2FA),
        foregroundColor: const Color(0xFF355BE7),
        disabledForegroundColor: const Color(0xFF9DA5B8),
        disabledBackgroundColor: const Color(0xFFF3F5FA),
      ),
    );
  }
}

String _formatPlaybackDuration(Duration duration) {
  final clamped = duration.isNegative ? Duration.zero : duration;
  final totalSeconds = clamped.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

import 'package:flutter/material.dart';

import '../../../tts/domain/sherpa_tts_config.dart';
import 'settings_section_widgets.dart';

class VoiceSettingsControls extends StatelessWidget {
  const VoiceSettingsControls({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  final SherpaTtsConfig config;
  final Future<void> Function(SherpaTtsConfig config) onConfigChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsNumberCard(
          title: 'Speech Speed',
          valueLabel: config.speed.toStringAsFixed(2),
          child: Slider(
            value: config.speed,
            min: 0.6,
            max: 1.4,
            divisions: 8,
            onChanged: (value) =>
                onConfigChanged(config.copyWith(speed: value)),
          ),
        ),
        const SizedBox(height: 14),
        SettingsNumberCard(
          title: 'Speaker ID',
          valueLabel: '${config.speakerId}',
          child: Slider(
            value: config.speakerId.toDouble(),
            min: 0,
            max: 903,
            divisions: 903,
            onChanged: (value) =>
                onConfigChanged(config.copyWith(speakerId: value.round())),
          ),
        ),
      ],
    );
  }
}

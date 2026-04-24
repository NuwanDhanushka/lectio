import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_services_providers.dart';
import '../../../offline_ai/data/offline_ai_model_service.dart';
import '../../../tts/presentation/controllers/sherpa_tts_service.dart';
import '../widgets/offline_ai_settings_card.dart';
import '../widgets/settings_section_widgets.dart';
import '../widgets/voice_settings_controls.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SherpaTtsService ttsService = ref.watch(sherpaTtsServiceProvider);
    final OfflineAiModelService aiModelService =
        ref.watch(offlineAiModelServiceProvider);
    final settingsListenable = Listenable.merge([
      ttsService,
      aiModelService,
    ]);

    return SafeArea(
      child: AnimatedBuilder(
        animation: settingsListenable,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          children: [
            const SettingsHeader(
              title: 'Voice Settings',
              subtitle: 'Manage offline voice and AI features.',
            ),
            const SizedBox(height: 22),
            OfflineAiSettingsCard(
              state: aiModelService.state,
              onModelSelected: aiModelService.selectModel,
              onDownloadPressed: aiModelService.downloadSelectedModel,
              onDeletePressed: aiModelService.deleteSelectedModel,
            ),
            const SizedBox(height: 18),
            const SettingsSectionLabel('Voice'),
            const SizedBox(height: 12),
            VoiceSettingsControls(
              config: ttsService.config,
              onConfigChanged: ttsService.updateConfig,
            ),
          ],
        ),
      ),
    );
  }
}

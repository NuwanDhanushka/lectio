import 'package:flutter/material.dart';

import '../../../offline_ai/data/offline_ai_model_service.dart';
import '../../../offline_ai/domain/offline_ai_model.dart';

class OfflineAiSettingsCard extends StatelessWidget {
  const OfflineAiSettingsCard({
    super.key,
    required this.state,
    required this.onModelSelected,
    required this.onDownloadPressed,
    required this.onDeletePressed,
  });

  final OfflineAiModelState state;
  final Future<void> Function(OfflineAiModel model) onModelSelected;
  final Future<void> Function() onDownloadPressed;
  final Future<void> Function() onDeletePressed;

  @override
  Widget build(BuildContext context) {
    final selectedModel = state.selectedModel;
    final isDownloading = state.status == OfflineAiModelStatus.downloading;
    final isReady = state.status == OfflineAiModelStatus.ready;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F2A56), Color(0xFF5368E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A5368E8),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Download once. Summaries run privately on device.',
                      style: TextStyle(
                        color: Color(0xFFD9E2FF),
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Model',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<OfflineAiModel>(
                    value: selectedModel,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF26356F),
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    items: [
                      for (final model in offlineAiModels)
                        DropdownMenuItem(
                          value: model,
                          child: Text('${model.name} (${model.sizeLabel})'),
                        ),
                    ],
                    onChanged: isDownloading || isReady
                        ? null
                        : (model) {
                            if (model != null) {
                              onModelSelected(model);
                            }
                          },
                  ),
                ),
                Text(
                  selectedModel.description,
                  style: const TextStyle(
                    color: Color(0xFFD9E2FF),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AiModelStatusRow(state: state),
          if (isDownloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: state.downloadProgress <= 0
                    ? null
                    : state.downloadProgress.clamp(0, 1).toDouble(),
                minHeight: 6,
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              state.errorMessage!,
              style: const TextStyle(
                color: Color(0xFFFFD4D4),
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed:
                      isDownloading || isReady ? null : onDownloadPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.34),
                    foregroundColor: const Color(0xFF355BE7),
                    disabledForegroundColor: Colors.white70,
                  ),
                  child: Text(isReady ? 'Ready' : 'Download Model'),
                ),
              ),
              if (isReady) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: onDeletePressed,
                  tooltip: 'Delete model',
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AiModelStatusRow extends StatelessWidget {
  const _AiModelStatusRow({required this.state});

  final OfflineAiModelState state;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (state.status) {
      OfflineAiModelStatus.ready => (
          Icons.check_circle_rounded,
          'Ready for offline AI'
        ),
      OfflineAiModelStatus.downloading => (
          Icons.downloading_rounded,
          'Downloading ${(state.downloadProgress * 100).round()}%'
        ),
      OfflineAiModelStatus.error => (
          Icons.error_outline_rounded,
          'Needs attention'
        ),
      OfflineAiModelStatus.notInstalled => (
          Icons.cloud_download_outlined,
          'Not installed'
        ),
    };

    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 19),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

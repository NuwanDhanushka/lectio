class OfflineAiModel {
  const OfflineAiModel({
    required this.id,
    required this.name,
    required this.fileName,
    required this.sizeLabel,
    required this.description,
    required this.downloadUrl,
    required this.sha256,
  });

  final String id;
  final String name;
  final String fileName;
  final String sizeLabel;
  final String description;
  final String downloadUrl;
  final String sha256;

  bool get hasDownloadUrl => downloadUrl.trim().isNotEmpty;
}

const offlineAiModels = [
  OfflineAiModel(
    id: 'qwen3_5_2b_q4_k_m',
    name: 'Qwen3.5 2B',
    fileName: 'Qwen3.5-2B-Q4_K_M.gguf',
    sizeLabel: '~1.3 GB',
    description: 'Balanced offline summaries and explanations for Lectio.',
    downloadUrl:
        'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf',
    sha256: 'aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223',
  ),
];

OfflineAiModel offlineAiModelById(String id) {
  return offlineAiModels.firstWhere(
    (model) => model.id == id,
    orElse: () => offlineAiModels.first,
  );
}

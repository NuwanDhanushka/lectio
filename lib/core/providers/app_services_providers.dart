import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/data/document_import_service.dart';
import '../../features/library/data/library_repository.dart';
import '../../features/offline_ai/data/offline_ai_model_service.dart';
import '../../features/tts/presentation/controllers/sherpa_tts_service.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => SqliteLibraryRepository.instance,
);

final documentImportServiceProvider = Provider<DocumentImportService>(
  (ref) => DocumentImportService(
    repository: ref.watch(libraryRepositoryProvider),
  ),
);

final sherpaTtsServiceProvider = Provider<SherpaTtsService>((ref) {
  final service = SherpaTtsService.instance;
  service.ensureInitialized();
  return service;
});

final offlineAiModelServiceProvider = Provider<OfflineAiModelService>((ref) {
  final service = OfflineAiModelService.instance;
  service.ensureInitialized();
  return service;
});

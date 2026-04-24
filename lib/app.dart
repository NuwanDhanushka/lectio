import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/providers/app_services_providers.dart';
import 'core/providers/app_shell_controller.dart';
import 'core/widgets/bottom_nav.dart';
import 'features/library/data/library_repository.dart';
import 'features/library/presentation/pages/home_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/reader/presentation/pages/details_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';

final appShellControllerProvider =
    ChangeNotifierProvider<AppShellController>((ref) {
  return AppShellController();
});

class LectioApp extends StatelessWidget {
  const LectioApp({
    super.key,
    this.repository,
  });

  final LibraryRepository? repository;

  @override
  Widget build(BuildContext context) {
    final libraryRepository = repository ?? SqliteLibraryRepository.instance;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4C63F5),
    );

    return ProviderScope(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(libraryRepository),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Lectio',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F6FB),
          colorScheme: colorScheme,
          textTheme: GoogleFonts.interTextTheme(
            const TextTheme(
              headlineMedium: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Color(0xFF202430),
              ),
              titleLarge: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF202430),
              ),
              bodyLarge: TextStyle(
                fontSize: 16,
                color: Color(0xFF6F7585),
              ),
            ),
          ),
        ),
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(libraryRepositoryProvider);
    final shellController = ref.watch(appShellControllerProvider);
    final shellState = shellController.state;

    final List<Widget> pages = [
      HomePage(
        onOpenDocument: (item) => shellController.openReaderFor(item),
      ),
      DetailsPage(
        item: shellState.selectedItem,
        repository: repository,
        initialPage: shellState.initialReaderPage,
        onBottomNavVisibilityChanged: shellController.setBottomNavVisible,
        onItemUpdated: shellController.updateSelectedItem,
      ),
      ProfilePage(
        repository: repository,
        onOpenDocument: (item, {initialPage}) =>
            shellController.openReaderFor(item, initialPage: initialPage),
      ),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: shellState.selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: shellState.selectedIndex,
        onTap: shellController.selectIndex,
        isVisible: shellState.isBottomNavVisible,
      ),
    );
  }
}

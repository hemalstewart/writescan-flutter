import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_state.dart';
import '../features/auth/view/auth_page.dart';
import '../features/bots/view/bots_screen.dart';
import '../features/bots/view/bot_chat_page.dart';
import '../features/general_chat/view/general_chat_screen.dart';
import '../features/home/view/home_screen.dart';
import '../features/more/view/more_screen.dart';
import '../features/onboarding/view/onboarding_page.dart';
import '../features/shell/view/app_shell.dart';
import '../features/splash/view/splash_page.dart';
import '../features/scan/view/scan_placeholder.dart';
import '../features/scan/view/csv_scan_page.dart';
import '../features/scan/view/handwriting_scan_page.dart';
import '../features/scan/view/empty_document_page.dart';
import '../features/home/state/home_state.dart';
import '../features/bots/state/bots_state.dart';
import '../features/documents/view/documents_screen.dart';
import '../features/documents/view/document_viewer_page.dart';
import '../features/bots/view/create_bot_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefreshStream(
    ref.watch(authControllerProvider.notifier).stream,
  );
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      // Simple guard: if not active, redirect to auth.
      final isAuthed =
          ref.read(authControllerProvider).stage == AuthStage.loggedIn;
      final path = state.uri.path;
      const publicPaths = {'/auth', '/splash', '/onboarding'};
      if (!isAuthed && !publicPaths.contains(path)) {
        return '/auth';
      }
      if (isAuthed && (path == '/auth' || path == '/onboarding')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SplashPage()),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AuthPage()),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: OnboardingPage()),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/documents',
            name: 'documents',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DocumentsScreen()),
          ),
          GoRoute(
            path: '/documents/view',
            name: 'documentViewer',
            pageBuilder: (context, state) {
              final doc = state.extra;
              if (doc is DocumentItem) {
                return NoTransitionPage(
                  child: DocumentViewerPage(document: doc),
                );
              }
              return const NoTransitionPage(child: DocumentsScreen());
            },
          ),
          GoRoute(
            path: '/folders/:id',
            name: 'folderDetail',
            pageBuilder: (context, state) {
              final folderId = state.pathParameters['id'] ?? '';
              final extra = state.extra;
              String? folderName;
              if (extra is Folder) {
                folderName = extra.name;
              } else {
                folderName = state.uri.queryParameters['name'];
              }
              return NoTransitionPage(
                child: DocumentsScreen(
                  folderId: folderId,
                  folderName: folderName,
                ),
              );
            },
          ),
          GoRoute(
            path: '/bots',
            name: 'bots',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BotsScreen()),
          ),
          GoRoute(
            path: '/bots/create',
            name: 'createBot',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CreateBotScreen()),
          ),
          GoRoute(
            path: '/chat',
            name: 'chat',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: GeneralChatScreen()),
          ),
          GoRoute(
            path: '/botChat',
            name: 'botChat',
            pageBuilder: (context, state) {
              final bot = state.extra;
              if (bot is Map<String, dynamic>) {
                final id = bot['id'] as String? ?? '';
                final name = bot['name'] as String? ?? 'Bot';
                final source = bot['source'] as String? ?? '';
                final tags = (bot['tags'] as List<dynamic>? ?? [])
                    .map((e) => e.toString())
                    .toList();
                final botObj = Bot(
                  id: id,
                  name: name,
                  source: source,
                  tags: tags,
                );
                return NoTransitionPage(child: BotChatPage(bot: botObj));
              }
              return const NoTransitionPage(child: GeneralChatScreen());
            },
          ),
          GoRoute(
            path: '/more',
            name: 'more',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MoreScreen()),
          ),
          GoRoute(
            path: '/scan',
            name: 'scan',
            builder: (context, state) {
              final kind = state.extra as DocumentKind? ?? DocumentKind.normal;
              return ScanPlaceholderPage(kind: kind);
            },
          ),
          GoRoute(
            path: '/scan/csv',
            name: 'scanCsv',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CsvScanPage()),
          ),
          GoRoute(
            path: '/scan/handwriting',
            name: 'scanHandwriting',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HandwritingScanPage()),
          ),
          GoRoute(
            path: '/scan/empty',
            name: 'scanEmpty',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmptyDocumentPage()),
          ),
        ],
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

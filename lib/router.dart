import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/activity/activity_screen.dart';
import 'features/add/quick_add_screen.dart';
import 'features/auth/auth_screens.dart';
import 'features/clients/client_detail_screen.dart';
import 'features/clients/client_form_screen.dart';
import 'features/clients/clients_screen.dart';
import 'features/home/home_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/transactions/transaction_detail_screen.dart';
import 'providers/app_providers.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _clientsKey = GlobalKey<NavigatorState>(debugLabel: 'clients');
final _addKey = GlobalKey<NavigatorState>(debugLabel: 'add');
final _activityKey = GlobalKey<NavigatorState>(debugLabel: 'activity');
final _settingsKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

/// Routes that are reachable while signed out.
const _publicRoutes = {'/login', '/signup', '/forgot-password'};

/// The app router.
///
/// Built once and kept for the life of the app; auth changes are pushed in
/// through [refreshListenable] so the redirect re-runs without tearing down
/// navigation state.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);
  final refresh = GoRouterRefreshStream(auth.authStateChanges());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = auth.currentUser != null;
      final location = state.matchedLocation;
      final onPublicRoute = _publicRoutes.contains(location);

      if (!signedIn && !onPublicRoute) return '/login';
      if (signedIn && onPublicRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _clientsKey,
            routes: [
              GoRoute(
                path: '/clients',
                builder: (context, state) => const ClientsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _addKey,
            routes: [
              GoRoute(
                path: '/add',
                builder: (context, state) => const QuickAddScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _activityKey,
            routes: [
              GoRoute(
                path: '/activity',
                builder: (context, state) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _settingsKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Pushed over the shell so the bottom bar gets out of the way on the
      // screens where the content is the whole point.
      GoRoute(
        path: '/clients/new',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ClientFormScreen(),
      ),
      GoRoute(
        path: '/clients/:clientId',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => ClientDetailScreen(
          clientId: state.pathParameters['clientId']!,
        ),
        routes: [
          GoRoute(
            path: 'edit',
            parentNavigatorKey: _rootKey,
            builder: (context, state) => ClientFormScreen(
              clientId: state.pathParameters['clientId']!,
            ),
          ),
          GoRoute(
            path: 'tx/:transactionId',
            parentNavigatorKey: _rootKey,
            builder: (context, state) => TransactionDetailScreen(
              clientId: state.pathParameters['clientId']!,
              transactionId: state.pathParameters['transactionId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/reports',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ReportsScreen(),
      ),
    ],
    errorBuilder: (context, state) => _RouteNotFound(location: state.uri.path),
  );
});

/// Bridges a stream into a [Listenable] for `GoRouter.refreshListenable`.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off_outlined, size: 40),
            const SizedBox(height: 14),
            Text('Nothing here', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(location, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    );
  }
}

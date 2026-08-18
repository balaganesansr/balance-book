import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/client_service.dart';
import '../services/notification_service.dart';
import '../services/portal_service.dart';
import '../services/prefs_service.dart';
import '../services/profile_service.dart';
import '../services/project_service.dart';
import '../services/transaction_service.dart';

/// Service singletons.
///
/// Screens never construct a service or touch Firestore directly. They read
/// one of these, which keeps every widget testable by overriding a provider.

const _auth = AuthService();
const _clients = ClientService();
const _transactions = TransactionService();
const _projects = ProjectService();
const _profiles = ProfileService();
const _portal = PortalService();

final authServiceProvider = Provider<AuthService>((ref) => _auth);
final clientServiceProvider = Provider<ClientService>((ref) => _clients);
final transactionServiceProvider =
    Provider<TransactionService>((ref) => _transactions);
final projectServiceProvider = Provider<ProjectService>((ref) => _projects);
final profileServiceProvider = Provider<ProfileService>((ref) => _profiles);
final portalServiceProvider = Provider<PortalService>((ref) => _portal);

/// Overridden in `main()` once shared preferences have loaded, so the rest of
/// the app can read it synchronously.
final prefsProvider = Provider<PrefsService>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

/// Overridden in `main()` after the plugin has initialised.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => throw UnimplementedError(
    'notificationServiceProvider must be overridden',
  ),
);

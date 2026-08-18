import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'auth_providers.dart';

/// Refreshes a client's shared balance page after anything that changes what
/// the client would see.
///
/// Deliberately fire-and-forget: the share page is a convenience, and a failure
/// to refresh it must never surface as a failed charge or payment. The ledger
/// write has already committed by the time this runs.
void syncSharePage(WidgetRef ref, String clientId) {
  final uid = ref.read(currentUidProvider);
  if (uid == null) return;
  ref.read(portalServiceProvider).syncQuietly(
    uid: uid,
    clientId: clientId,
    currencyCode: ref.read(currencyProvider).code,
  );
}

# Contributing to Balance Book

Thanks for taking a look. Bug reports, feature ideas and pull requests are all
welcome.

## Getting set up

You need Flutter **3.47+** (pinned in `.fvmrc`, so `fvm use` picks it up) and a
Firebase project of your own. See [Quick start](README.md#quick-start).

```bash
flutter pub get
flutter analyze     # must stay at 0 issues
flutter test        # must stay green
```

For the security rules you also need Java and Node:

```bash
npm --prefix firestore-tests install
firebase emulators:exec --only firestore --project demo-balance-book \
  "npm --prefix firestore-tests test"
```

## The one rule that shapes everything

**A balance is never set. It is only ever the result of a transaction.**

Almost every convention below follows from that. If a change would break it,
it is the wrong change, even if it is shorter.

### Money

- Every amount is an `int` of minor units (paise, cents). **Never introduce a
  `double` into a balance path**, including "just for display".
- `lib/core/utils/money.dart` is the only place money is formatted or parsed.
  Nothing else divides by 100.
- `amount` is always positive and is what the user typed. `delta` is the signed
  effect on the balance. Compute balances from `delta`, never by switching on
  the type enum. The sign of money is decided in exactly one place,
  `TxDraft.delta`.

### Writes

- Only `TransactionService` writes `currentBalance`, and only inside a
  `runTransaction` that reads the client document first. Do not add a second
  writer, and do not update a balance from a widget.
- `runningBalance` is the balance *after* an entry. That is why an amount can
  never be edited in place.

### Correcting a transaction

| Situation | Do this |
|---|---|
| Wrong description | Edit it (`editDetails`) |
| Wrong amount or type | **Reverse** it, then add a fresh entry |
| Mistake just made | Permanent delete, newest entry only |

The "is it still the newest entry" check must stay *inside* the Firestore
transaction, compared against the client's `lastTransactionId`. Do not relax it
to a query.

## Layering

```
widget → provider → service → Firestore
```

No widget imports `cloud_firestore`. Screens read a Riverpod provider, providers
call a service, and services own every Firestore path
(`lib/services/firestore_refs.dart`).

## Firestore

- Everything a user owns lives under `users/{uid}`. Keep it that way. It is
  what reduces the security rules to a single ownership comparison.
- Adding a query? Check whether `firestore.indexes.json` needs a composite index
  and whether `firestore.rules` still permits it. Collection-group queries must
  filter on `userId`.
- Writes are online-only by design. Do not queue balance changes offline; that
  would mean reporting a payment as saved before it was.
- Anything added to `PortalService.buildSnapshot` becomes visible to a client
  holding a share link. That payload is an explicit allow-list and there is a
  test asserting its exact key set. If your change trips that test, it is doing
  its job. Decide deliberately rather than just updating the expectation.

## UI conventions

- Prose is plain and specific. "₹17,000 outstanding", not "Balance: 17000". Say
  what an action will do before it is irreversible.
- Confirm destructive things (delete, archive, reverse). Do **not** confirm
  routine ones (add charge, record payment). Those get a toast. The speed of
  those two flows is a feature.
- Disable a submit button while its write is in flight, *and* guard with a flag.
  Duplicate financial writes are the failure mode that matters most.
- Semantic colours come from `AppColors` (`context.colors`). No raw hex in
  widgets.
- The app draws edge-to-edge. Use the helpers in `core/utils/safe_insets.dart`
  for anything near the bottom of the screen. `showModalBottomSheet` does
  **not** avoid the navigation bar on its own.

## Pull requests

- Keep `flutter analyze` at zero issues.
- Add tests for anything touching money, balances, rules or the public snapshot.
- Describe the user-visible change, not just the code change.
- Small and focused beats large and sweeping.

## Reporting a security issue

Please do not open a public issue for anything affecting data isolation or the
security rules. Open a private security advisory on the repository instead.

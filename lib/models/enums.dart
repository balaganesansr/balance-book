/// What a transaction did to the balance.
///
/// The *type* is descriptive; the authoritative effect on the balance is the
/// signed `delta` stored on every transaction. Nothing derives the balance by
/// switching on this enum.
enum TxType { opening, charge, payment, adjustment, reversal }

extension TxTypeX on TxType {
  String get id => name;

  static TxType fromId(String? id) =>
      TxType.values.firstWhere((t) => t.name == id, orElse: () => TxType.charge);

  String get label => switch (this) {
    TxType.opening => 'Opening balance',
    TxType.charge => 'Charge',
    TxType.payment => 'Payment',
    TxType.adjustment => 'Adjustment',
    TxType.reversal => 'Reversal',
  };

  String get shortLabel => switch (this) {
    TxType.opening => 'Opening',
    TxType.charge => 'Charge',
    TxType.payment => 'Payment',
    TxType.adjustment => 'Adjustment',
    TxType.reversal => 'Reversal',
  };
}

/// Manual lifecycle state a user can put a client in.
enum ClientStatus { active, inactive, archived }

extension ClientStatusX on ClientStatus {
  String get id => name;

  static ClientStatus fromId(String? id) => ClientStatus.values.firstWhere(
    (s) => s.name == id,
    orElse: () => ClientStatus.active,
  );

  String get label => switch (this) {
    ClientStatus.active => 'Active',
    ClientStatus.inactive => 'Inactive',
    ClientStatus.archived => 'Archived',
  };
}

/// Derived from the balance. Never stored.
enum BalanceState { outstanding, settled, credit }

extension BalanceStateX on BalanceState {
  static BalanceState of(int balance) {
    if (balance > 0) return BalanceState.outstanding;
    if (balance < 0) return BalanceState.credit;
    return BalanceState.settled;
  }

  String get label => switch (this) {
    BalanceState.outstanding => 'Outstanding',
    BalanceState.settled => 'Settled',
    BalanceState.credit => 'Credit',
  };
}

/// Lifecycle of a project. Projects are organisational labels. They group a
/// client's transactions and never hold a balance of their own.
enum ProjectStatus { active, completed, archived }

extension ProjectStatusX on ProjectStatus {
  String get id => name;

  static ProjectStatus fromId(String? id) => ProjectStatus.values.firstWhere(
    (s) => s.name == id,
    orElse: () => ProjectStatus.active,
  );

  String get label => switch (this) {
    ProjectStatus.active => 'Active',
    ProjectStatus.completed => 'Completed',
    ProjectStatus.archived => 'Archived',
  };
}

/// How a payment came in. Free text is allowed; these are just quick picks.
class PaymentMethods {
  const PaymentMethods._();

  static const upi = 'UPI';
  static const cash = 'Cash';
  static const bankTransfer = 'Bank transfer';
  static const card = 'Card';
  static const cheque = 'Cheque';
  static const other = 'Other';

  static const all = <String>[upi, cash, bankTransfer, card, cheque, other];
}

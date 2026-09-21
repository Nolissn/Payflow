import 'billing_cycle.dart';
import 'expense_status.dart';
import 'notice_period.dart';

const _unset = Object();

/// A recurring financial commitment: a subscription, contract, insurance
/// premium, membership, …
///
/// Immutable; use [copyWith] to derive changed versions. [toJson]/[fromJson]
/// are storage-agnostic so the same model can be persisted locally or synced
/// with Firebase / Supabase later.
class RecurringExpense {
  const RecurringExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.cycle,
    required this.nextPaymentDate,
    this.status = ExpenseStatus.active,
    this.startDate,
    this.endDate,
    this.noticePeriod,
    this.note,
    this.url,
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// Name or provider, e.g. "Netflix".
  final String name;

  /// Price charged per [cycle], in the user's currency.
  final double amount;
  final String categoryId;
  final BillingCycle cycle;

  /// The next known charge date. Acts as the anchor of the payment schedule;
  /// if it lies in the past the schedule rolls forward automatically.
  final DateTime nextPaymentDate;
  final ExpenseStatus status;
  final DateTime? startDate;

  /// No charges happen after this date (e.g. fixed-term contract).
  final DateTime? endDate;

  /// Cancellation notice required before a renewal. `null` = none / unknown.
  final NoticePeriod? noticePeriod;
  final String? note;
  final String? url;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RecurringExpense copyWith({
    String? name,
    double? amount,
    String? categoryId,
    BillingCycle? cycle,
    DateTime? nextPaymentDate,
    ExpenseStatus? status,
    Object? startDate = _unset,
    Object? endDate = _unset,
    Object? noticePeriod = _unset,
    Object? note = _unset,
    Object? url = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringExpense(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      cycle: cycle ?? this.cycle,
      nextPaymentDate: nextPaymentDate ?? this.nextPaymentDate,
      status: status ?? this.status,
      startDate:
          identical(startDate, _unset) ? this.startDate : startDate as DateTime?,
      endDate: identical(endDate, _unset) ? this.endDate : endDate as DateTime?,
      noticePeriod: identical(noticePeriod, _unset)
          ? this.noticePeriod
          : noticePeriod as NoticePeriod?,
      note: identical(note, _unset) ? this.note : note as String?,
      url: identical(url, _unset) ? this.url : url as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'categoryId': categoryId,
        'cycle': cycle.toJson(),
        'nextPaymentDate': nextPaymentDate.toIso8601String(),
        'status': status.name,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'noticePeriod': noticePeriod?.toJson(),
        'note': note,
        'url': url,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory RecurringExpense.fromJson(Map<String, Object?> json) {
    DateTime? date(String key) {
      final value = json[key] as String?;
      return value == null ? null : DateTime.parse(value);
    }

    final notice = json['noticePeriod'] as Map<String, Object?>?;
    return RecurringExpense(
      id: json['id']! as String,
      name: json['name']! as String,
      amount: (json['amount']! as num).toDouble(),
      categoryId: json['categoryId']! as String,
      cycle: BillingCycle.fromJson(json['cycle']! as Map<String, Object?>),
      nextPaymentDate: date('nextPaymentDate')!,
      status: ExpenseStatus.values.byName(json['status'] as String? ?? 'active'),
      startDate: date('startDate'),
      endDate: date('endDate'),
      noticePeriod: notice == null ? null : NoticePeriod.fromJson(notice),
      note: json['note'] as String?,
      url: json['url'] as String?,
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecurringExpense &&
      other.id == id &&
      other.name == name &&
      other.amount == amount &&
      other.categoryId == categoryId &&
      other.cycle == cycle &&
      other.nextPaymentDate == nextPaymentDate &&
      other.status == status &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.noticePeriod == noticePeriod &&
      other.note == note &&
      other.url == url;

  @override
  int get hashCode => Object.hash(id, name, amount, categoryId, cycle,
      nextPaymentDate, status, startDate, endDate, noticePeriod, note, url);
}

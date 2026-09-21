import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/formatting/date_format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/date_math.dart';
import '../../domain/models/billing_cycle.dart';
import '../../domain/models/category.dart';
import '../../domain/models/expense_status.dart';
import '../../domain/models/notice_period.dart';
import '../../domain/models/recurring_expense.dart';
import '../../domain/services/cost_calculator.dart';
import '../../shared/widgets/category_visuals.dart';
import '../../state/app_scope.dart';
import 'expense_templates.dart';

/// Opens the add / edit sheet. Returns the saved expense, or `null`.
Future<RecurringExpense?> showExpenseForm(
  BuildContext context, {
  RecurringExpense? existing,
}) {
  return showModalBottomSheet<RecurringExpense>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ExpenseFormSheet(existing: existing),
  );
}

class ExpenseFormSheet extends StatefulWidget {
  const ExpenseFormSheet({super.key, this.existing});

  final RecurringExpense? existing;

  @override
  State<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _customCount;
  late final TextEditingController _noticeCount;
  late final TextEditingController _url;
  late final TextEditingController _note;

  late BillingFrequency _frequency;
  late CycleUnit _customUnit;
  late String _categoryId;
  late DateTime _nextPayment;
  late ExpenseStatus _status;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _hasNotice;
  late NoticeUnit _noticeUnit;
  late bool _showDetails;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final today = DateMath.dateOnly(DateTime.now());
    _name = TextEditingController(text: e?.name ?? '');
    _amount = TextEditingController(
        text: e == null ? '' : e.amount.toStringAsFixed(2));
    _frequency = e?.cycle.frequency ?? BillingFrequency.monthly;
    _customUnit = e?.cycle.unit ?? CycleUnit.month;
    _customCount = TextEditingController(
        text: '${e != null && _frequency == BillingFrequency.custom ? e.cycle.count : 2}');
    _categoryId = e?.categoryId ?? DefaultCategories.streaming.id;
    _nextPayment = e?.nextPaymentDate ?? today;
    _status = e?.status ?? ExpenseStatus.active;
    _startDate = e?.startDate;
    _endDate = e?.endDate;
    _hasNotice = e?.noticePeriod != null;
    _noticeUnit = e?.noticePeriod?.unit ?? NoticeUnit.day;
    _noticeCount =
        TextEditingController(text: '${e?.noticePeriod?.count ?? 30}');
    _url = TextEditingController(text: e?.url ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _showDetails = e != null &&
        (e.noticePeriod != null ||
            e.startDate != null ||
            e.endDate != null ||
            (e.note?.isNotEmpty ?? false) ||
            (e.url?.isNotEmpty ?? false) ||
            e.status != ExpenseStatus.active);

    for (final c in [_amount, _customCount, _noticeCount]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _amount, _customCount, _noticeCount, _url, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _parsedAmount =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.'));

  BillingCycle get _cycle {
    if (_frequency != BillingFrequency.custom) {
      return BillingCycle.fromFrequency(_frequency);
    }
    final count = int.tryParse(_customCount.text) ?? 1;
    return BillingCycle(_customUnit, count.clamp(1, 999));
  }

  NoticePeriod? get _notice {
    if (!_hasNotice) return null;
    final count = int.tryParse(_noticeCount.text);
    return count == null ? null : NoticePeriod(count, _noticeUnit);
  }

  void _applyTemplate(ExpenseTemplate t) {
    HapticFeedback.selectionClick();
    setState(() {
      _name.text = t.name;
      _amount.text = t.amount.toStringAsFixed(2);
      _categoryId = t.category.id;
      _frequency = t.cycle.frequency;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }
    setState(() => _saving = true);
    final store = ExpenseScope.read(context);
    final url = _url.text.trim();
    final note = _note.text.trim();
    final base = widget.existing ??
        RecurringExpense(
          id: const Uuid().v4(),
          name: '',
          amount: 0,
          categoryId: _categoryId,
          cycle: BillingCycle.monthly,
          nextPaymentDate: _nextPayment,
        );
    final expense = base.copyWith(
      name: _name.text.trim(),
      amount: _parsedAmount,
      categoryId: _categoryId,
      cycle: _cycle,
      nextPaymentDate: _nextPayment,
      status: _status,
      startDate: _startDate,
      endDate: _endDate,
      noticePeriod: _notice,
      url: url.isEmpty ? null : _normalizeUrl(url),
      note: note.isEmpty ? null : note,
    );
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await store.save(expense);
      HapticFeedback.mediumImpact();
      navigator.pop(expense);
      messenger.showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Changes saved' : '${expense.name} added'),
      ));
    } catch (e) {
      setState(() => _saving = false);
      messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't save. Please try again.")));
    }
  }

  static String _normalizeUrl(String url) =>
      url.contains('://') ? url : 'https://$url';

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? first}) {
    final today = DateMath.dateOnly(DateTime.now());
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateMath.addMonths(today, -12 * 30),
      lastDate: DateMath.addMonths(today, 12 * 30),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEdit ? 'Edit expense' : 'New recurring expense',
                        style: context.text.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (!_isEdit) ...[
                      _QuickPicks(onPick: _applyTemplate),
                      const SizedBox(height: 18),
                    ],
                    TextFormField(
                      controller: _name,
                      autofocus: !_isEdit,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name or provider',
                        hintText: 'e.g. Netflix',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Give it a name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: context.text.headlineSmall!.figures,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        prefixText: '${context.settings.currency.symbol} ',
                        prefixStyle: context.text.headlineSmall!
                            .copyWith(color: c.textMuted),
                      ),
                      validator: (v) {
                        final value =
                            double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (value == null) return 'Enter a price';
                        if (value <= 0) return 'Price must be above zero';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _Label('Payment interval'),
                    _FrequencyPicker(
                      value: _frequency,
                      onChanged: (f) => setState(() => _frequency = f),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: _frequency == BillingFrequency.custom
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _CountUnitRow<CycleUnit>(
                                prefix: 'Every',
                                controller: _customCount,
                                unit: _customUnit,
                                units: CycleUnit.values,
                                unitLabel: (u, n) => u.label(n),
                                onUnitChanged: (u) =>
                                    setState(() => _customUnit = u),
                                minimum: 1,
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    _ConversionPreview(amount: _parsedAmount, cycle: _cycle),
                    const SizedBox(height: 18),
                    _Label('Category'),
                    _CategoryPicker(
                      selectedId: _categoryId,
                      categories: context.store.categories,
                      onChanged: (id) => setState(() => _categoryId = id),
                    ),
                    const SizedBox(height: 18),
                    _DateField(
                      label: 'Next payment',
                      icon: Icons.event_rounded,
                      value: _nextPayment,
                      onTap: () async {
                        final picked = await _pickDate(_nextPayment);
                        if (picked != null) setState(() => _nextPayment = picked);
                      },
                    ),
                    const SizedBox(height: 8),
                    _DetailsToggle(
                      expanded: _showDetails,
                      onTap: () => setState(() => _showDetails = !_showDetails),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _showDetails
                          ? _buildDetails(context)
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
              _SaveBar(
                label: _isEdit ? 'Save changes' : 'Add expense',
                saving: _saving,
                onSave: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    final notice = _notice;
    final c = context.colors;
    final renewal = _nextPayment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _Label('Status'),
        SegmentedButton<ExpenseStatus>(
          segments: [
            for (final s in ExpenseStatus.values)
              ButtonSegment(value: s, label: Text(s.label)),
          ],
          selected: {_status},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _status = s.first),
        ),
        const SizedBox(height: 18),
        _Label('Cancellation period'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Has a notice period'),
          subtitle: const Text('Payflow calculates your latest cancellation date'),
          value: _hasNotice,
          onChanged: (v) => setState(() => _hasNotice = v),
        ),
        if (_hasNotice) ...[
          _CountUnitRow<NoticeUnit>(
            controller: _noticeCount,
            unit: _noticeUnit,
            units: NoticeUnit.values,
            unitLabel: (u, n) => u.label(n),
            onUnitChanged: (u) => setState(() => _noticeUnit = u),
            minimum: 0,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text('before each renewal', style: context.text.bodySmall),
          ),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(Brand.radiusM),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: c.onAccentSoft),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Renewal ${Dates.long(renewal)} → cancel by '
                        '${Dates.long(notice.latestCancellationFor(renewal))}',
                        style: context.text.labelLarge!
                            .copyWith(color: c.onAccentSoft),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 18),
        _Label('Contract'),
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: 'Start date',
                icon: Icons.play_arrow_rounded,
                value: _startDate,
                optional: true,
                onClear: () => setState(() => _startDate = null),
                onTap: () async {
                  final picked = await _pickDate(_startDate ?? DateTime.now());
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateField(
                label: 'End date',
                icon: Icons.stop_rounded,
                value: _endDate,
                optional: true,
                onClear: () => setState(() => _endDate = null),
                onTap: () async {
                  final picked = await _pickDate(_endDate ?? _nextPayment);
                  if (picked != null) setState(() => _endDate = picked);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextFormField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Provider website (optional)',
            hintText: 'netflix.com/account',
            prefixIcon: Icon(Icons.link_rounded),
          ),
          validator: (v) {
            final value = v?.trim() ?? '';
            if (value.isEmpty) return null;
            final uri = Uri.tryParse(_normalizeUrl(value));
            return uri == null || !uri.host.contains('.')
                ? 'That doesn’t look like a web address'
                : null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _note,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: context.text.labelLarge!
                .copyWith(color: context.colors.textSecondary)),
      );
}

class _QuickPicks extends StatelessWidget {
  const _QuickPicks({required this.onPick});
  final ValueChanged<ExpenseTemplate> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Quick add'),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: expenseTemplates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final t = expenseTemplates[i];
              return ActionChip(
                avatar: Icon(CategoryVisuals.icon(t.category),
                    size: 16, color: CategoryVisuals.color(context, t.category)),
                label: Text(t.name),
                onPressed: () => onPick(t),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FrequencyPicker extends StatelessWidget {
  const _FrequencyPicker({required this.value, required this.onChanged});

  final BillingFrequency value;
  final ValueChanged<BillingFrequency> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in BillingFrequency.values)
          ChoiceChip(
            label: Text(f.label),
            selected: value == f,
            onSelected: (_) => onChanged(f),
          ),
      ],
    );
  }
}

/// Live preview of the central interval conversion: "€10.00 / month".
class _ConversionPreview extends StatelessWidget {
  const _ConversionPreview({required this.amount, required this.cycle});

  final double? amount;
  final BillingCycle cycle;

  @override
  Widget build(BuildContext context) {
    final a = amount;
    if (a == null || a <= 0) return const SizedBox(height: 4);
    final money = context.money;
    final c = context.colors;
    final parts = <String>[
      if (cycle != BillingCycle.monthly)
        '${money(CostCalculator.convert(a, cycle, CostPeriod.month))} / month',
      if (cycle != BillingCycle.yearly)
        '${money(CostCalculator.convert(a, cycle, CostPeriod.year))} / year',
      '${money(CostCalculator.convert(a, cycle, CostPeriod.day))} / day',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.primarySoft,
          borderRadius: BorderRadius.circular(Brand.radiusM),
        ),
        child: Row(
          children: [
            Icon(Icons.swap_horiz_rounded, size: 18, color: c.onPrimarySoft),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                parts.join('  ·  '),
                style: context.text.labelLarge!.figures
                    .copyWith(color: c.onPrimarySoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.selectedId,
    required this.categories,
    required this.onChanged,
  });

  final String selectedId;
  final List<ExpenseCategory> categories;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final cat in categories)
          ChoiceChip(
            avatar: Icon(
              CategoryVisuals.icon(cat),
              size: 16,
              color: selectedId == cat.id
                  ? Theme.of(context).colorScheme.onPrimary
                  : CategoryVisuals.color(context, cat),
            ),
            label: Text(cat.name),
            selected: selectedId == cat.id,
            onSelected: (_) => onChanged(cat.id),
          ),
      ],
    );
  }
}

class _CountUnitRow<U extends Enum> extends StatelessWidget {
  const _CountUnitRow({
    required this.controller,
    required this.unit,
    required this.units,
    required this.unitLabel,
    required this.onUnitChanged,
    required this.minimum,
    this.prefix,
    this.suffix,
  });

  final TextEditingController controller;
  final U unit;
  final List<U> units;
  final String Function(U unit, int count) unitLabel;
  final ValueChanged<U> onUnitChanged;
  final int minimum;
  final String? prefix;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final count = int.tryParse(controller.text) ?? 1;
    return Row(
      children: [
        if (prefix != null) ...[
          Text(prefix!, style: context.text.titleSmall),
          const SizedBox(width: 12),
        ],
        SizedBox(
          width: 76,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < minimum ? 'Min. $minimum' : null;
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<U>(
            initialValue: unit,
            isExpanded: true,
            items: [
              for (final u in units)
                DropdownMenuItem(value: u, child: Text(unitLabel(u, count))),
            ],
            onChanged: (u) => u == null ? null : onUnitChanged(u),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(suffix!,
                style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
          ),
        ],
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    this.optional = false,
    this.onClear,
  });

  final String label;
  final IconData icon;
  final DateTime? value;
  final VoidCallback onTap;
  final bool optional;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Brand.radiusM),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: optional && value != null
              ? IconButton(
                  tooltip: 'Clear $label',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                )
              : null,
        ),
        child: Text(
          value == null ? 'Not set' : Dates.withYear(value!),
          style: context.text.bodyLarge!.copyWith(
            color: value == null ? c.textMuted : c.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DetailsToggle extends StatelessWidget {
  const _DetailsToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Brand.radiusM),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Status, cancellation period, contract, notes',
                style: context.text.labelLarge!
                    .copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more_rounded, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.label,
    required this.saving,
    required this.onSave,
  });

  final String label;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

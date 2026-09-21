import 'package:flutter/material.dart';

import '../../../core/formatting/date_format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand.dart';
import '../../../domain/services/payment_schedule.dart';
import '../../../shared/widgets/expense_tiles.dart';
import '../../../state/app_scope.dart';

/// Horizontally scrolling cards for upcoming payments above the
/// "large payment" threshold — noticeable without shouting.
class LargePaymentsStrip extends StatelessWidget {
  const LargePaymentsStrip({super.key, required this.payments});

  final List<PaymentOccurrence> payments;

  @override
  Widget build(BuildContext context) {
    final today = context.store.overview.today;
    final c = context.colors;
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: payments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final p = payments[i];
          return SizedBox(
            width: 190,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => openExpense(context, p.expense),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: c.accent),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${Dates.short(p.date, reference: today)} · '
                              '${Dates.relative(p.date, today)}',
                              style: context.text.labelMedium!
                                  .copyWith(color: c.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Text(p.expense.name,
                                style: context.text.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                context.money(p.amount),
                                style: context.text.headlineSmall!.figures
                                    .copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(p.expense.cycle.label,
                                style: context.text.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

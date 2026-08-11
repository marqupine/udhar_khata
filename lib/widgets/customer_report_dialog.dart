import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/models.dart';
import '../services/udhar_repository.dart';
import '../theme/app_theme.dart';

class CustomerReportDialog extends StatelessWidget {
  final Customer customer;
  final UdharRepository repository;

  const CustomerReportDialog({
    super.key,
    required this.customer,
    required this.repository,
  });

  static Future<void> show(
    BuildContext context, {
    required Customer customer,
    required UdharRepository repository,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CustomerReportDialog(
        customer: customer,
        repository: repository,
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour:$minute $period';
  }

  String _buildFormattedTextReport(
    List<GoodItem> goods,
    double totalBorrowed,
    double totalPaid,
    double pendingBalance,
  ) {
    final nowStr = _formatDateTime(DateTime.now());
    final buffer = StringBuffer();

    buffer.writeln('📄 *${AppConstants.appName.toUpperCase()} PENDING DUES STATEMENT*');
    buffer.writeln('========================================');
    buffer.writeln('Customer: ${customer.name}');
    if (customer.phoneNumber.isNotEmpty) {
      buffer.writeln('Phone: ${customer.phoneNumber}');
    }
    if (customer.address.isNotEmpty) {
      buffer.writeln('Address: ${customer.address}');
    }
    buffer.writeln('Generated: $nowStr');
    buffer.writeln('========================================');
    buffer.writeln('*FINANCIAL SUMMARY*');
    buffer.writeln('Total Borrowed: ₹${totalBorrowed.toStringAsFixed(2)}');
    buffer.writeln('Total Paid: ₹${totalPaid.toStringAsFixed(2)}');
    buffer.writeln('Net Outstanding Debt: ₹${pendingBalance.toStringAsFixed(2)}');
    buffer.writeln('========================================');
    buffer.writeln('*OUTSTANDING ITEMS DETAILS (${goods.length} Items)*\n');

    if (goods.isEmpty) {
      buffer.writeln('All clear! No pending dues found.');
    } else {
      for (int i = 0; i < goods.length; i++) {
        final item = goods[i];
        final qtyStr = item.quantity.toStringAsFixed(
          item.quantity.truncateToDouble() == item.quantity ? 0 : 1,
        );
        buffer.writeln('${i + 1}. *${item.name}* (${item.category})');
        buffer.writeln('   📅 Borrowed: ${_formatDateTime(item.date)}');
        buffer.writeln(
          '   📦 Qty: $qtyStr @ ₹${item.unitPrice.toStringAsFixed(2)} = ₹${item.totalPrice.toStringAsFixed(2)}',
        );
        buffer.writeln(
          '   💳 Status: ${item.statusLabel} (Paid: ₹${item.amountPaid.toStringAsFixed(2)} | Net Due: ₹${item.remainingAmount.toStringAsFixed(2)})',
        );
        buffer.writeln('');
      }
    }

    buffer.writeln('========================================');
    buffer.writeln('Please clear your pending dues soon. Thank you!');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final allGoods = repository.getGoodsForCustomer(customer.id);
    final dueGoods = allGoods.where((g) => g.remainingAmount > 0.001).toList();
    final totalBorrowed = repository.getCustomerTotalBorrowed(customer.id);
    final totalPaid = repository.getCustomerTotalPaid(customer.id);
    final pendingBalance = repository.getCustomerPendingBalance(customer.id);
    final reportText = _buildFormattedTextReport(
      dueGoods,
      totalBorrowed,
      totalPaid,
      pendingBalance,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 600,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header with Store Branding
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.saffronPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assessment_rounded,
                    color: AppTheme.saffronDark,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Dues Report',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Generated on ${_formatDateTime(DateTime.now())}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Profile Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.saffronPrimary.withValues(
                              alpha: 0.2,
                            ),
                            foregroundColor: AppTheme.saffronDark,
                            radius: 20,
                            child: Text(
                              customer.name.isNotEmpty
                                  ? customer.name[0].toUpperCase()
                                  : 'C',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (customer.phoneNumber.isNotEmpty ||
                                    customer.address.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (customer.phoneNumber.isNotEmpty)
                                        customer.phoneNumber,
                                      if (customer.address.isNotEmpty)
                                        customer.address,
                                    ].join(' • '),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Financial Summary Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryBox(
                            label: 'Total Borrowed',
                            value: '₹${totalBorrowed.toStringAsFixed(2)}',
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryBox(
                            label: 'Total Paid',
                            value: '₹${totalPaid.toStringAsFixed(2)}',
                            color: AppTheme.paidText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryBox(
                            label: 'Net Due',
                            value: '₹${pendingBalance.toStringAsFixed(2)}',
                            color:
                                pendingBalance > 0.001
                                    ? AppTheme.pendingText
                                    : AppTheme.paidText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section Heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Outstanding Items (${dueGoods.length} Items)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Itemized Table List
                    if (dueGoods.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: const Text(
                          'No pending dues! All borrowed items are fully settled.',
                          style: TextStyle(
                            color: AppTheme.paidText,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dueGoods.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = dueGoods[index];
                          final qtyStr = item.quantity.toStringAsFixed(
                            item.quantity.truncateToDouble() == item.quantity
                                ? 0
                                : 1,
                          );

                          Color statusBg =
                              item.isPaid
                                  ? AppTheme.paidBg
                                  : (item.isPartiallyPaid
                                      ? AppTheme.partialBg
                                      : AppTheme.pendingBg);
                          Color statusText =
                              item.isPaid
                                  ? AppTheme.paidText
                                  : (item.isPartiallyPaid
                                      ? AppTheme.partialText
                                      : AppTheme.pendingText);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '#${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.statusLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: statusText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Borrow Time: ${_formatDateTime(item.date)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• ${item.category}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Divider(height: 1),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$qtyStr qty × ₹${item.unitPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      'Total: ₹${item.totalPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.amountPaid > 0.001) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Paid: ₹${item.amountPaid.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.paidText,
                                        ),
                                      ),
                                      Text(
                                        'Due: ₹${item.remainingAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.pendingText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Action Buttons Footer
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text(
                      'Copy Text for WhatsApp',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: reportText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Report text copied to Clipboard! Ready to paste in WhatsApp.',
                          ),
                          backgroundColor: AppTheme.saffronPrimary,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Done'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

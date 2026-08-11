import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/udhar_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/add_goods_dialog.dart';
import '../widgets/animated_reminder_button.dart';
import '../widgets/customer_report_dialog.dart';
import '../widgets/record_payment_dialog.dart';

enum GoodsFilter { defaultFilter, newest, oldest, range }

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  final UdharRepository repository;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    required this.repository,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GoodsFilter _goodsFilter = GoodsFilter.defaultFilter;
  DateTimeRange? _selectedDateRange;
  bool _isHeaderCollapsed = false;

  List<GoodItem> _getFilteredGoods(List<GoodItem> allGoods) {
    List<GoodItem> list;
    switch (_goodsFilter) {
      case GoodsFilter.defaultFilter:
        list = allGoods.where((g) => !g.isPaid).toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
      case GoodsFilter.newest:
        list = List.from(allGoods);
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
      case GoodsFilter.oldest:
        list = List.from(allGoods);
        list.sort((a, b) => a.date.compareTo(b.date));
        break;
      case GoodsFilter.range:
        if (_selectedDateRange != null) {
          final start = DateTime(
            _selectedDateRange!.start.year,
            _selectedDateRange!.start.month,
            _selectedDateRange!.start.day,
            0,
            0,
            0,
          );
          final end = DateTime(
            _selectedDateRange!.end.year,
            _selectedDateRange!.end.month,
            _selectedDateRange!.end.day,
            23,
            59,
            59,
            999,
          );
          list =
              allGoods
                  .where((g) => !g.date.isBefore(start) && !g.date.isAfter(end))
                  .toList();
        } else {
          list = List.from(allGoods);
        }
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddGoodsDialog(
    Customer customer, {
    bool isLegacyMode = false,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => AddGoodsDialog(
            customerName: customer.name,
            isLegacyMode: isLegacyMode,
          ),
    );

    if (result != null) {
      await widget.repository.addGoodItem(
        customerId: customer.id,
        name: result['name'],
        category: result['category'],
        quantity: result['quantity'],
        unitPrice: result['unitPrice'],
        date: result['date'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isLegacyMode
                  ? 'Added paper book record "${result['name']}" for ${customer.name}'
                  : 'Added "${result['name']}" for ${customer.name}',
            ),
            backgroundColor: isLegacyMode ? Colors.purple : AppTheme.primary,
          ),
        );
      }
    }
  }

  void _openEditGoodsDialog(Customer customer, GoodItem item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) =>
              AddGoodsDialog(customerName: customer.name, existingItem: item),
    );

    if (result != null) {
      await widget.repository.updateGoodItem(
        id: item.id,
        name: result['name'],
        category: result['category'],
        quantity: result['quantity'],
        unitPrice: result['unitPrice'],
        date: result['date'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated "${result['name']}" successfully'),
            backgroundColor: AppTheme.saffronPrimary,
          ),
        );
      }
    }
  }

  void _openRecordPaymentDialog(Customer customer) async {
    final pending = widget.repository.getCustomerPendingBalance(customer.id);
    if (pending <= 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This customer has no pending balance to pay!'),
          backgroundColor: AppTheme.primary,
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => RecordPaymentDialog(
            customer: customer,
            repository: widget.repository,
          ),
    );

    if (result != null) {
      final payment = await widget.repository.recordPayment(
        customerId: customer.id,
        paymentAmount: result['amount'],
        note: result['note'],
      );

      if (payment != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded payment of ₹${result['amount']} with FIFO settlement!',
            ),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'grocery':
        return Icons.shopping_cart_outlined;
      case 'snacks':
        return Icons.fastfood_outlined;
      case 'beverages':
        return Icons.local_drink_outlined;
      case 'dairy':
        return Icons.opacity_outlined;
      case 'vegetables':
        return Icons.eco_outlined;
      case 'electronics':
        return Icons.devices_outlined;
      default:
        return Icons.store_outlined;
    }
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

  void _openRecycleBinBottomSheet(Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      backgroundColor: AppTheme.surface,
      builder: (context) {
        return ListenableBuilder(
          listenable: widget.repository,
          builder: (context, _) {
            final binGoods = widget.repository.getRecycleBinGoods(customer.id);
            final now = DateTime.now();

            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_delete_outlined,
                            color: AppTheme.pendingText,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Recycle Bin (${binGoods.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Items in Recycle Bin are automatically deleted after 72 hours.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Expanded(
                    child:
                        binGoods.isEmpty
                            ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_sweep_outlined,
                                    size: 48,
                                    color: AppTheme.textMuted,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Recycle Bin is empty',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              itemCount: binGoods.length,
                              itemBuilder: (context, index) {
                                final item = binGoods[index];
                                final deletedAt = item.deletedAt ?? item.date;
                                final hoursLeft = (72 -
                                        now.difference(deletedAt).inHours)
                                    .clamp(0, 72);

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
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
                                            Text(
                                              '₹${item.totalPrice.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: AppTheme.pendingText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.timer_outlined,
                                              size: 12,
                                              color: AppTheme.saffronDark,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Expires in ${hoursLeft}h',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.saffronDark,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '• Deleted ${_formatDateTime(deletedAt)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              icon: const Icon(
                                                Icons
                                                    .restore_from_trash_outlined,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'Restore',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppTheme.primary,
                                              ),
                                              onPressed: () async {
                                                await widget.repository
                                                    .restoreFromBin(item.id);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Restored "${item.name}" back to borrowed goods',
                                                      ),
                                                      backgroundColor:
                                                          AppTheme.primary,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              icon: const Icon(
                                                Icons.delete_forever_outlined,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'Delete',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppTheme.pendingText,
                                              ),
                                              onPressed: () async {
                                                final confirm = await showDialog<
                                                  bool
                                                >(
                                                  context: context,
                                                  builder:
                                                      (context) => AlertDialog(
                                                        title: const Text(
                                                          'Delete Permanently?',
                                                        ),
                                                        content: Text(
                                                          'Permanently remove "${item.name}"? This action cannot be undone.',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(
                                                                      false,
                                                                    ),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  AppTheme
                                                                      .pendingText,
                                                            ),
                                                            onPressed:
                                                                () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(true),
                                                            child: const Text(
                                                              'Delete Permanently',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                                if (confirm == true) {
                                                  await widget.repository
                                                      .permanentlyDeleteGood(
                                                        item.id,
                                                      );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
    int badgeCount = 0,
  }) {
    Widget iconWidget = Icon(icon, size: 20, color: color);

    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text(
          '$badgeCount',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.pendingText,
        textColor: Colors.white,
        child: iconWidget,
      );
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant.withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.cardBorder.withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          child: iconWidget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final customer = widget.repository.getCustomerById(widget.customerId);

        if (customer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Customer Details')),
            body: const Center(child: Text('Customer not found')),
          );
        }

        final totalBorrowed = widget.repository.getCustomerTotalBorrowed(
          customer.id,
        );
        final totalPaid = widget.repository.getCustomerTotalPaid(customer.id);
        final pendingBalance = widget.repository.getCustomerPendingBalance(
          customer.id,
        );

        final goods = widget.repository.getGoodsForCustomer(customer.id);
        final filteredGoods = _getFilteredGoods(goods);
        final binGoods = widget.repository.getRecycleBinGoods(customer.id);
        final payments = widget.repository.getPaymentsForCustomer(customer.id);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Row(
                  children: [
                    if (customer.phoneNumber.isNotEmpty) ...[
                      Text(
                        customer.phoneNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (customer.phoneNumber.isNotEmpty &&
                        customer.address.isNotEmpty) ...[
                      const Text(
                        ' • ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                    if (customer.address.isNotEmpty) ...[
                      Flexible(
                        child: Text(
                          customer.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            actions: [
              _buildHeaderActionButton(
                icon: Icons.assessment_outlined,
                color: AppTheme.saffronPrimary,
                tooltip: 'Consolidated Customer Report',
                onPressed:
                    () => CustomerReportDialog.show(
                      context,
                      customer: customer,
                      repository: widget.repository,
                    ),
              ),
              const SizedBox(width: 6),
              AnimatedReminderButton(
                customer: customer,
                repository: widget.repository,
              ),
              const SizedBox(width: 6),
              _buildHeaderActionButton(
                icon: Icons.auto_delete_outlined,
                color: AppTheme.textSecondary,
                tooltip: 'Recycle Bin (${binGoods.length})',
                badgeCount: binGoods.length,
                onPressed: () => _openRecycleBinBottomSheet(customer),
              ),
              const SizedBox(width: 6),
              _buildHeaderActionButton(
                icon: Icons.cleaning_services_outlined,
                color: AppTheme.pendingText,
                tooltip: 'Clear Customer Records (Move to Bin)',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: const Text('Clear Customer Records?'),
                          content: Text(
                            'Are you sure you want to clear all transaction records for "${customer.name}"?\n\nAll borrowed items will be soft-deleted and moved to the Recycle Bin, where they can be restored or will be automatically purged after 72 hours.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.pendingText,
                              ),
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Move to Bin'),
                            ),
                          ],
                        ),
                  );

                  if (confirm == true) {
                    await widget.repository.clearCustomerRecords(customer.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'All records for ${customer.name} moved to Recycle Bin (72h auto-purge).',
                          ),
                          backgroundColor: AppTheme.saffronPrimary,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Column(
            children: [
              // Summary Financial Header (Collapsible for Full Screen View)
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState:
                    _isHeaderCollapsed
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Pending Balance & Badge Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pending Balance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${pendingBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        pendingBalance > 0.001
                                            ? AppTheme.pendingText
                                            : AppTheme.paidText,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        pendingBalance > 0.001
                                            ? AppTheme.pendingBg
                                            : AppTheme.paidBg,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    pendingBalance > 0.001
                                        ? 'DEBT PENDING'
                                        : 'ALL CLEAR',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          pendingBalance > 0.001
                                              ? AppTheme.pendingText
                                              : AppTheme.paidText,
                                    ),
                                  ),
                                ),
                                if (customer.addedByUserName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Added by ${customer.addedByUserName}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: AppTheme.cardBorder),
                        const SizedBox(height: 8),

                        // Total Borrowed & Total Paid metrics
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Text(
                                    'Borrowed: ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  Text(
                                    '₹${totalBorrowed.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 16,
                              color: AppTheme.cardBorder,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12.0),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Paid: ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    Text(
                                      '₹${totalPaid.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.paidText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Streamlined Action Buttons Row (3 in 1 row)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 6,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(
                                  Icons.add_shopping_cart,
                                  size: 15,
                                ),
                                label: const Text(
                                  'Add Goods',
                                  style: TextStyle(fontSize: 11),
                                ),
                                onPressed: () => _openAddGoodsDialog(customer),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: AppTheme.paidBg.withValues(
                                    alpha: 0.4,
                                  ),
                                  side: const BorderSide(
                                    color: AppTheme.paidText,
                                  ),
                                  foregroundColor: AppTheme.paidText,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 6,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.payment, size: 15),
                                label: const Text(
                                  'Record Pay',
                                  style: TextStyle(fontSize: 11),
                                ),
                                onPressed:
                                    () => _openRecordPaymentDialog(customer),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.purple.withValues(
                                    alpha: 0.05,
                                  ),
                                  side: BorderSide(
                                    color: Colors.purple.withValues(alpha: 0.4),
                                  ),
                                  foregroundColor: Colors.purple,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 6,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(
                                  Icons.menu_book_rounded,
                                  size: 15,
                                ),
                                label: const Text(
                                  'Paper Book',
                                  style: TextStyle(fontSize: 11),
                                ),
                                onPressed:
                                    () => _openAddGoodsDialog(
                                      customer,
                                      isLegacyMode: true,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                secondChild: Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Text(
                                'Pending: ₹${pendingBalance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      pendingBalance > 0.001
                                          ? AppTheme.pendingText
                                          : AppTheme.paidText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• Borrowed: ₹${totalBorrowed.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.add_shopping_cart,
                              size: 18,
                              color: AppTheme.saffronPrimary,
                            ),
                            tooltip: 'Add Goods',
                            onPressed: () => _openAddGoodsDialog(customer),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.payment,
                              size: 18,
                              color: AppTheme.paidText,
                            ),
                            tooltip: 'Record Payment',
                            onPressed: () => _openRecordPaymentDialog(customer),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.menu_book_rounded,
                              size: 18,
                              color: Colors.purple,
                            ),
                            tooltip: 'Paper Book Entry',
                            onPressed:
                                () => _openAddGoodsDialog(
                                  customer,
                                  isLegacyMode: true,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Tab Bar & Full Screen Toggle Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AppTheme.primary,
                        labelColor: AppTheme.primary,
                        unselectedLabelColor: AppTheme.textSecondary,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        tabs: [
                          Tab(text: 'Borrowed Goods (${filteredGoods.length})'),
                          Tab(text: 'Payment Receipts (${payments.length})'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isHeaderCollapsed
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: AppTheme.saffronPrimary,
                        size: 20,
                      ),
                      tooltip:
                          _isHeaderCollapsed
                              ? 'Show Full Summary'
                              : 'Maximize List Height',
                      onPressed: () {
                        setState(() {
                          _isHeaderCollapsed = !_isHeaderCollapsed;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Goods List with Filters
                    Column(
                      children: [
                        // Filter Bar
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                FilterChip(
                                  showCheckmark: false,
                                  label: const Text('Default (Unpaid)'),
                                  selected:
                                      _goodsFilter == GoodsFilter.defaultFilter,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _goodsFilter =
                                            GoodsFilter.defaultFilter;
                                      });
                                    }
                                  },
                                  selectedColor: AppTheme.saffronPrimary
                                      .withValues(alpha: 0.2),
                                  side: BorderSide(
                                    color:
                                        _goodsFilter ==
                                                GoodsFilter.defaultFilter
                                            ? AppTheme.saffronPrimary
                                            : AppTheme.cardBorder,
                                  ),
                                  labelStyle: TextStyle(
                                    fontWeight:
                                        _goodsFilter ==
                                                GoodsFilter.defaultFilter
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color:
                                        _goodsFilter ==
                                                GoodsFilter.defaultFilter
                                            ? AppTheme.saffronDark
                                            : AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  showCheckmark: false,
                                  label: const Text('Newest'),
                                  selected: _goodsFilter == GoodsFilter.newest,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _goodsFilter = GoodsFilter.newest;
                                      });
                                    }
                                  },
                                  selectedColor: AppTheme.saffronPrimary
                                      .withValues(alpha: 0.2),
                                  side: BorderSide(
                                    color:
                                        _goodsFilter == GoodsFilter.newest
                                            ? AppTheme.saffronPrimary
                                            : AppTheme.cardBorder,
                                  ),
                                  labelStyle: TextStyle(
                                    fontWeight:
                                        _goodsFilter == GoodsFilter.newest
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color:
                                        _goodsFilter == GoodsFilter.newest
                                            ? AppTheme.saffronDark
                                            : AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  showCheckmark: false,
                                  label: const Text('Oldest'),
                                  selected: _goodsFilter == GoodsFilter.oldest,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _goodsFilter = GoodsFilter.oldest;
                                      });
                                    }
                                  },
                                  selectedColor: AppTheme.saffronPrimary
                                      .withValues(alpha: 0.2),
                                  side: BorderSide(
                                    color:
                                        _goodsFilter == GoodsFilter.oldest
                                            ? AppTheme.saffronPrimary
                                            : AppTheme.cardBorder,
                                  ),
                                  labelStyle: TextStyle(
                                    fontWeight:
                                        _goodsFilter == GoodsFilter.oldest
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color:
                                        _goodsFilter == GoodsFilter.oldest
                                            ? AppTheme.saffronDark
                                            : AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  showCheckmark: false,
                                  avatar: Icon(
                                    Icons.date_range_outlined,
                                    size: 15,
                                    color:
                                        _goodsFilter == GoodsFilter.range
                                            ? AppTheme.saffronDark
                                            : AppTheme.textSecondary,
                                  ),
                                  label: Text(
                                    _goodsFilter == GoodsFilter.range &&
                                            _selectedDateRange != null
                                        ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}'
                                        : 'Range',
                                  ),
                                  selected: _goodsFilter == GoodsFilter.range,
                                  onSelected: (selected) async {
                                    final picked = await showDateRangePicker(
                                      context: context,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 1),
                                      ),
                                      initialDateRange:
                                          _selectedDateRange ??
                                          DateTimeRange(
                                            start: DateTime.now().subtract(
                                              const Duration(days: 30),
                                            ),
                                            end: DateTime.now(),
                                          ),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: AppTheme.saffronPrimary,
                                              onPrimary: Colors.white,
                                              surface: AppTheme.surface,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _selectedDateRange = picked;
                                        _goodsFilter = GoodsFilter.range;
                                      });
                                    } else if (_selectedDateRange != null) {
                                      setState(() {
                                        _goodsFilter = GoodsFilter.range;
                                      });
                                    }
                                  },
                                  selectedColor: AppTheme.saffronPrimary
                                      .withValues(alpha: 0.2),
                                  side: BorderSide(
                                    color:
                                        _goodsFilter == GoodsFilter.range
                                            ? AppTheme.saffronPrimary
                                            : AppTheme.cardBorder,
                                  ),
                                  labelStyle: TextStyle(
                                    fontWeight:
                                        _goodsFilter == GoodsFilter.range
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color:
                                        _goodsFilter == GoodsFilter.range
                                            ? AppTheme.saffronDark
                                            : AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Goods List
                        Expanded(
                          child:
                              filteredGoods.isEmpty
                                  ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.shopping_bag_outlined,
                                          size: 48,
                                          color: AppTheme.textMuted,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _goodsFilter ==
                                                      GoodsFilter
                                                          .defaultFilter &&
                                                  goods.isNotEmpty
                                              ? 'No unpaid goods found.'
                                              : _goodsFilter ==
                                                      GoodsFilter.range &&
                                                  _selectedDateRange != null
                                              ? 'No goods in selected range.'
                                              : 'No goods added yet.',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _goodsFilter ==
                                                      GoodsFilter
                                                          .defaultFilter &&
                                                  goods.isNotEmpty
                                              ? 'All borrowed items have been fully settled!'
                                              : 'Tap "+ Add Goods" above to log borrowed items.',
                                          style: const TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      16,
                                    ),
                                    itemCount: filteredGoods.length,
                                    itemBuilder: (context, index) {
                                      final item = filteredGoods[index];
                                      final progress =
                                          item.totalPrice > 0
                                              ? (item.amountPaid /
                                                      item.totalPrice)
                                                  .clamp(0.0, 1.0)
                                              : 1.0;

                                      Color statusBg;
                                      Color statusText;
                                      if (item.isPaid) {
                                        statusBg = AppTheme.paidBg;
                                        statusText = AppTheme.paidText;
                                      } else if (item.isPartiallyPaid) {
                                        statusBg = AppTheme.partialBg;
                                        statusText = AppTheme.partialText;
                                      } else {
                                        statusBg = AppTheme.pendingBg;
                                        statusText = AppTheme.pendingText;
                                      }

                                      return Dismissible(
                                        key: ValueKey(item.id),
                                        direction: DismissDirection.startToEnd,
                                        background: Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          padding: const EdgeInsets.only(
                                            left: 20,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.pendingBg,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.pendingText
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: const Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                color: AppTheme.pendingText,
                                                size: 24,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Move to Bin',
                                                style: TextStyle(
                                                  color: AppTheme.pendingText,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        confirmDismiss: (direction) async {
                                          final confirmed = await showDialog<
                                            bool
                                          >(
                                            context: context,
                                            builder:
                                                (context) => AlertDialog(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  title: const Text(
                                                    'Move to Recycle Bin?',
                                                  ),
                                                  content: Text(
                                                    'Are you sure you want to move "${item.name}" (₹${item.totalPrice.toStringAsFixed(2)}) to the Recycle Bin?\n\nIt will be permanently deleted after 72 hours if not restored.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.of(
                                                            context,
                                                          ).pop(false),
                                                      child: const Text(
                                                        'Cancel',
                                                        style: TextStyle(
                                                          color:
                                                              AppTheme
                                                                  .textSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                AppTheme
                                                                    .pendingText,
                                                          ),
                                                      onPressed:
                                                          () => Navigator.of(
                                                            context,
                                                          ).pop(true),
                                                      child: const Text(
                                                        'Move to Bin',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          );
                                          return confirmed ?? false;
                                        },
                                        onDismissed: (direction) async {
                                          await widget.repository.moveToBin(
                                            item.id,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).clearSnackBars();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Moved "${item.name}" to Recycle Bin',
                                                ),
                                                duration: const Duration(
                                                  seconds: 4,
                                                ),
                                                action: SnackBarAction(
                                                  label: 'UNDO',
                                                  textColor: AppTheme.royalGold,
                                                  onPressed: () async {
                                                    await widget.repository
                                                        .restoreFromBin(
                                                          item.id,
                                                        );
                                                  },
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        child: Card(
                                          child: Padding(
                                            padding: const EdgeInsets.all(14.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primary
                                                            .withValues(
                                                              alpha: 0.08,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        _getCategoryIcon(
                                                          item.category,
                                                        ),
                                                        color: AppTheme.primary,
                                                        size: 20,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            item.name,
                                                            style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16,
                                                              color:
                                                                  AppTheme
                                                                      .textPrimary,
                                                            ),
                                                          ),
                                                          Text(
                                                            '${item.category} • ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} qty @ ₹${item.unitPrice.toStringAsFixed(2)}',
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  AppTheme
                                                                      .textSecondary,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 3,
                                                          ),
                                                          Row(
                                                            children: [
                                                              const Icon(
                                                                Icons
                                                                    .access_time_rounded,
                                                                size: 12,
                                                                color:
                                                                    AppTheme
                                                                        .textMuted,
                                                              ),
                                                              const SizedBox(
                                                                width: 3,
                                                              ),
                                                              Text(
                                                                'Borrowed: ${_formatDateTime(item.date)}',
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  color:
                                                                      AppTheme
                                                                          .textMuted,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: statusBg,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        item.statusLabel,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: statusText,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),

                                                // Progress bar & settlement info
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value: progress,
                                                    backgroundColor:
                                                        AppTheme.cardBorder,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(
                                                          item.isPaid
                                                              ? AppTheme
                                                                  .paidText
                                                              : item
                                                                  .isPartiallyPaid
                                                              ? AppTheme
                                                                  .partialText
                                                              : AppTheme
                                                                  .pendingText,
                                                        ),
                                                    minHeight: 6,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),

                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Paid: ₹${item.amountPaid.toStringAsFixed(2)} / ₹${item.totalPrice.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color:
                                                            AppTheme
                                                                .textSecondary,
                                                      ),
                                                    ),
                                                    Text(
                                                      item.isPaid
                                                          ? 'Settled'
                                                          : 'Pending: ₹${item.remainingAmount.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            item.isPaid
                                                                ? AppTheme
                                                                    .paidText
                                                                : AppTheme
                                                                    .pendingText,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (!item.isPaid ||
                                                    item.canBeEdited) ...[
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      if (item.canBeEdited) ...[
                                                        TextButton.icon(
                                                          style: TextButton.styleFrom(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                            minimumSize:
                                                                Size.zero,
                                                            tapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap,
                                                            foregroundColor:
                                                                Colors.blue,
                                                          ),
                                                          icon: const Icon(
                                                            Icons.edit_outlined,
                                                            size: 14,
                                                          ),
                                                          label: const Text(
                                                            'Edit Record',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed:
                                                              () =>
                                                                  _openEditGoodsDialog(
                                                                    customer,
                                                                    item,
                                                                  ),
                                                        ),
                                                        if (!item.isPaid)
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                      ],
                                                      if (!item.isPaid) ...[
                                                        TextButton.icon(
                                                          style: TextButton.styleFrom(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                            minimumSize:
                                                                Size.zero,
                                                            tapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap,
                                                            foregroundColor:
                                                                AppTheme
                                                                    .primary,
                                                          ),
                                                          icon: const Icon(
                                                            Icons
                                                                .check_circle_outline,
                                                            size: 14,
                                                          ),
                                                          label: const Text(
                                                            'Mark Item Settled',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () async {
                                                            await widget
                                                                .repository
                                                                .markGoodAsPaid(
                                                                  item.id,
                                                                );
                                                            if (context
                                                                .mounted) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    'Marked "${item.name}" as fully paid!',
                                                                  ),
                                                                  backgroundColor:
                                                                      AppTheme
                                                                          .primary,
                                                                ),
                                                              );
                                                            }
                                                          },
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ),

                    // Tab 2: Payment Receipts History
                    payments.isEmpty
                        ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 48,
                                color: AppTheme.textMuted,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No payment records yet.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: payments.length,
                          itemBuilder: (context, index) {
                            final receipt = payments[index];
                            return Card(
                              child: ExpansionTile(
                                shape: const Border(),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.paidBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: AppTheme.paidText,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  '₹${receipt.amountPaid.toStringAsFixed(2)} Payment',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${_formatDateTime(receipt.date)}'
                                  '${receipt.note.isNotEmpty ? ' • ${receipt.note}' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                children: [
                                  Container(
                                    color: AppTheme.background,
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'FIFO Settlement Breakdown:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        ...receipt.settlements.map(
                                          (s) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2.0,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  '• ${s.itemName}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  '+₹${s.amountApplied.toStringAsFixed(2)} ${s.isFullyPaidNow ? "(Cleared)" : "(Partial)"}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        s.isFullyPaidNow
                                                            ? AppTheme.paidText
                                                            : AppTheme
                                                                .partialText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/udhar_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/add_goods_dialog.dart';
import '../widgets/record_payment_dialog.dart';

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

class _CustomerDetailScreenState extends State<CustomerDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  void _openAddGoodsDialog(Customer customer, {bool isLegacyMode = false}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddGoodsDialog(
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
      builder: (context) => AddGoodsDialog(
        customerName: customer.name,
        existingItem: item,
      ),
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
      builder: (context) => RecordPaymentDialog(
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

        final totalBorrowed = widget.repository.getCustomerTotalBorrowed(customer.id);
        final totalPaid = widget.repository.getCustomerTotalPaid(customer.id);
        final pendingBalance = widget.repository.getCustomerPendingBalance(customer.id);

        final goods = widget.repository.getGoodsForCustomer(customer.id);
        final payments = widget.repository.getPaymentsForCustomer(customer.id);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Row(
                  children: [
                    if (customer.phoneNumber.isNotEmpty) ...[
                      Text(
                        customer.phoneNumber,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                    if (customer.phoneNumber.isNotEmpty && customer.address.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                    if (customer.address.isNotEmpty) ...[
                      Flexible(
                        child: Text(
                          customer.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.pendingText),
                tooltip: 'Clear Customer Records',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Clear Customer Records?'),
                      content: Text('Are you sure you want to delete all borrowed goods and payment receipts for "${customer.name}"?\n\nThis will reset their pending balance to ₹0.00 while keeping the customer account intact.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.pendingText),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Clear Records'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await widget.repository.clearCustomerRecords(customer.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('All transaction records for ${customer.name} have been cleared.'),
                          backgroundColor: AppTheme.saffronPrimary,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Summary Financial Cards Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pending Balance',
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${pendingBalance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: pendingBalance > 0.001 ? AppTheme.pendingText : AppTheme.paidText,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: pendingBalance > 0.001 ? AppTheme.pendingBg : AppTheme.paidBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  pendingBalance > 0.001 ? 'DEBT PENDING' : 'ALL CLEAR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: pendingBalance > 0.001 ? AppTheme.pendingText : AppTheme.paidText,
                                  ),
                                ),
                              ),
                              if (customer.addedByUserName.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person_outline, size: 12, color: AppTheme.textMuted),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Added by ${customer.addedByUserName}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppTheme.cardBorder),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Borrowed',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                                Text(
                                  '₹${totalBorrowed.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 28, color: AppTheme.cardBorder),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Paid',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                  Text(
                                    '₹${totalPaid.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppTheme.paidText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text('Add Goods'),
                            onPressed: () => _openAddGoodsDialog(customer),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.payment, size: 18),
                            label: const Text('Record Payment'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppTheme.paidBg.withValues(alpha: 0.4),
                              side: const BorderSide(color: AppTheme.paidText),
                              foregroundColor: AppTheme.paidText,
                            ),
                            onPressed: () => _openRecordPaymentDialog(customer),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.menu_book_rounded, size: 18, color: Colors.purple),
                        label: const Text(
                          'Paper Book / Historical Entry',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.purple.withValues(alpha: 0.05),
                          side: BorderSide(color: Colors.purple.withValues(alpha: 0.4)),
                          foregroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _openAddGoodsDialog(customer, isLegacyMode: true),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Tab bar
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'Borrowed Goods (${goods.length})'),
                  Tab(text: 'Payment Receipts (${payments.length})'),
                ],
              ),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Goods List
                    goods.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_bag_outlined, size: 48, color: AppTheme.textMuted),
                                SizedBox(height: 12),
                                Text(
                                  'No goods added yet.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                                ),
                                Text(
                                  'Tap "+ Add Goods" above to log borrowed items.',
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: goods.length,
                            itemBuilder: (context, index) {
                              final item = goods[index];
                              final progress = item.totalPrice > 0 ? (item.amountPaid / item.totalPrice).clamp(0.0, 1.0) : 1.0;

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

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withValues(alpha:0.08),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              _getCategoryIcon(item.category),
                                              color: AppTheme.primary,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  '${item.category} • ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} qty @ ₹${item.unitPrice.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusBg,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              item.statusLabel,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: statusText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Progress bar & settlement info
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: AppTheme.cardBorder,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            item.isPaid
                                                ? AppTheme.paidText
                                                : item.isPartiallyPaid
                                                    ? AppTheme.partialText
                                                    : AppTheme.pendingText,
                                          ),
                                          minHeight: 6,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Paid: ₹${item.amountPaid.toStringAsFixed(2)} / ₹${item.totalPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            item.isPaid
                                                ? 'Settled'
                                                : 'Pending: ₹${item.remainingAmount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: item.isPaid ? AppTheme.paidText : AppTheme.pendingText,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!item.isPaid || item.canBeEdited) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (item.canBeEdited) ...[
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  foregroundColor: Colors.blue,
                                                ),
                                                icon: const Icon(Icons.edit_outlined, size: 14),
                                                label: const Text(
                                                  'Edit Record',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                                onPressed: () => _openEditGoodsDialog(customer, item),
                                              ),
                                              if (!item.isPaid) const SizedBox(width: 8),
                                            ],
                                            if (!item.isPaid) ...[
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  foregroundColor: AppTheme.primary,
                                                ),
                                                icon: const Icon(Icons.check_circle_outline, size: 14),
                                                label: const Text(
                                                  'Mark Item Settled',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                                onPressed: () async {
                                                  await widget.repository.markGoodAsPaid(item.id);
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Marked "${item.name}" as fully paid!'),
                                                        backgroundColor: AppTheme.primary,
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
                              );
                            },
                          ),

                    // Tab 2: Payment Receipts History
                    payments.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textMuted),
                                SizedBox(height: 12),
                                Text(
                                  'No payment records yet.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
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
                                    child: const Icon(Icons.check, color: AppTheme.paidText, size: 20),
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
                                    '${receipt.date.day}/${receipt.date.month}/${receipt.date.year} ${receipt.date.hour}:${receipt.date.minute.toString().padLeft(2, '0')}'
                                    '${receipt.note.isNotEmpty ? ' • ${receipt.note}' : ''}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                  children: [
                                    Container(
                                      color: AppTheme.background,
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    '• ${s.itemName}',
                                                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                                                  ),
                                                  Text(
                                                    '+₹${s.amountApplied.toStringAsFixed(2)} ${s.isFullyPaidNow ? "(Cleared)" : "(Partial)"}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: s.isFullyPaidNow ? AppTheme.paidText : AppTheme.partialText,
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

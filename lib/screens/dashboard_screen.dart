import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/udhar_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/add_customer_dialog.dart';
import '../widgets/add_goods_dialog.dart';
import '../widgets/record_payment_dialog.dart';
import 'customer_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UdharRepository repository;

  const DashboardScreen({super.key, required this.repository});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _searchQuery = '';
  String _activeFilter = 'All'; // 'All', 'Owed', 'Settled'

  void _openAddCustomerDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddCustomerDialog(),
    );

    if (result != null) {
      final customer = await widget.repository.addCustomer(
        name: result['name']!,
        phoneNumber: result['phone']!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer "${customer.name}" created successfully!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  void _openAddGoodsDialog(Customer customer) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddGoodsDialog(customerName: customer.name),
    );

    if (result != null) {
      await widget.repository.addGoodItem(
        customerId: customer.id,
        name: result['name'],
        category: result['category'],
        quantity: result['quantity'],
        unitPrice: result['unitPrice'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${result['name']}" for ${customer.name}'),
            backgroundColor: AppTheme.primary,
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
            content: Text('Payment of ₹${result['amount']} recorded with FIFO settlement!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final allCustomers = widget.repository.customers;
        final grandPending = widget.repository.grandTotalPending;
        final grandSettled = widget.repository.grandTotalSettled;
        final activeBorrowers = widget.repository.activeBorrowersCount;

        // Filtering
        final filteredCustomers = allCustomers.where((c) {
          final matchesSearch = c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.phoneNumber.contains(_searchQuery);
          if (!matchesSearch) return false;

          final pending = widget.repository.getCustomerPendingBalance(c.id);
          if (_activeFilter == 'Owed') {
            return pending > 0.001;
          } else if (_activeFilter == 'Settled') {
            return pending <= 0.001;
          }
          return true;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.menu_book_rounded, color: AppTheme.primary, size: 26),
                SizedBox(width: 10),
                Text(
                  'Udhar Khata',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddCustomerDialog,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Add Customer'),
          ),
          body: CustomScrollView(
            slivers: [
              // Metric Summary Cards Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Grand Pending Balance Hero Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryDark, AppTheme.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha:0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Outstanding Debt',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha:0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$activeBorrowers Borrowers',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${grandPending.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFFA7F3D0), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Total Collected So Far: ₹${grandSettled.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Color(0xFFA7F3D0),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search bar
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search customer by name or phone...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 12),

                      // Filter chips
                      Row(
                        children: [
                          _buildFilterChip('All', 'All (${allCustomers.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Owed', 'Has Debt'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Settled', 'Cleared'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Customer List
              filteredCustomers.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.people_outline_rounded,
                              size: 54,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No customers match "$_searchQuery"'
                                  : 'No customers recorded yet.',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap "+ Add Customer" to create your first entry.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final customer = filteredCustomers[index];
                            final pending = widget.repository.getCustomerPendingBalance(customer.id);
                            final totalBorrowed = widget.repository.getCustomerTotalBorrowed(customer.id);
                            final hasDebt = pending > 0.001;

                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => CustomerDetailScreen(
                                        customerId: customer.id,
                                        repository: widget.repository,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppTheme.primary.withValues(alpha:0.12),
                                            foregroundColor: AppTheme.primary,
                                            radius: 22,
                                            child: Text(
                                              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
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
                                                Text(
                                                  customer.phoneNumber,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '₹${pending.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: hasDebt ? AppTheme.pendingText : AppTheme.paidText,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: hasDebt ? AppTheme.pendingBg : AppTheme.paidBg,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  hasDebt ? 'PENDING' : 'CLEARED',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: hasDebt ? AppTheme.pendingText : AppTheme.paidText,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(height: 1, color: AppTheme.cardBorder),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Total Items Borrowed: ₹${totalBorrowed.toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.add_shopping_cart, size: 20, color: AppTheme.primary),
                                                tooltip: 'Add Goods',
                                                onPressed: () => _openAddGoodsDialog(customer),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.payment, size: 20, color: AppTheme.paidText),
                                                tooltip: 'Record Payment',
                                                onPressed: () => _openRecordPaymentDialog(customer),
                                              ),
                                              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: filteredCustomers.length,
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _activeFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primary.withValues(alpha:0.15),
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _activeFilter = filterKey;
          });
        }
      },
    );
  }
}

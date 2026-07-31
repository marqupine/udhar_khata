import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/udhar_repository.dart';
import '../theme/app_theme.dart';

class RecordPaymentDialog extends StatefulWidget {
  final Customer customer;
  final UdharRepository repository;

  const RecordPaymentDialog({
    super.key,
    required this.customer,
    required this.repository,
  });

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  double _totalPending = 0.0;
  List<ItemSettlementBreakdown> _previewBreakdown = [];

  @override
  void initState() {
    super.initState();
    _totalPending = widget.repository.getCustomerPendingBalance(widget.customer.id);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final amount = double.tryParse(val.trim()) ?? 0.0;
    setState(() {
      _previewBreakdown = widget.repository.previewFifoSettlement(widget.customer.id, amount);
    });
  }

  void _payFull() {
    _amountController.text = _totalPending.toStringAsFixed(2);
    _onAmountChanged(_amountController.text);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text.trim());
      Navigator.of(context).pop({
        'amount': amount,
        'note': _noteController.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.surface,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.paidBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.payments_outlined, color: AppTheme.paidText, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Record Customer Payment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'For ${widget.customer.name}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total Debt Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.pendingBg.withValues(alpha:0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.pendingText.withValues(alpha:0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Outstanding Balance:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.pendingText,
                      ),
                    ),
                    Text(
                      '₹${_totalPending.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.pendingText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount Input & Pay Full Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (₹) *',
                        hintText: '0.00',
                        prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppTheme.textSecondary),
                      ),
                      onChanged: _onAmountChanged,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Enter amount';
                        }
                        final d = double.tryParse(val.trim());
                        if (d == null || d <= 0) {
                          return 'Enter valid amount';
                        }
                        if (d > _totalPending + 0.01) {
                          return 'Exceeds balance';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: OutlinedButton(
                      onPressed: _payFull,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      child: const Text('Pay All'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note / Payment Mode (Optional)',
                  hintText: 'e.g. Cash, GPay, UPI',
                  prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),

              // Live FIFO Settlement Breakdown Preview Header
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  const Text(
                    'FIFO Auto-Settlement Preview (Oldest First)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Breakdown items preview list
              Expanded(
                child: currentAmount <= 0
                    ? Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: const Text(
                          'Enter payment amount to view itemized settlement allocation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          shrinkWrap: true,
                          itemCount: _previewBreakdown.length,
                          separatorBuilder: (_, __) => const Divider(height: 16, color: AppTheme.cardBorder),
                          itemBuilder: (context, index) {
                            final item = _previewBreakdown[index];
                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: item.isFullyPaidNow ? AppTheme.paidBg : AppTheme.partialBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.isFullyPaidNow ? 'SETTLED' : 'PARTIAL',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: item.isFullyPaidNow ? AppTheme.paidText : AppTheme.partialText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.itemName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Item Total: ₹${item.totalPrice.toStringAsFixed(2)} | Paid before: ₹${item.previousAmountPaid.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 11,
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
                                      '+₹${item.amountApplied.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.primaryDark,
                                      ),
                                    ),
                                    Text(
                                      'Rem: ₹${(item.totalPrice - item.newAmountPaid).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Confirm Payment'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

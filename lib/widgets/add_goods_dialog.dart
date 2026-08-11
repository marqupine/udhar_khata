import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class AddGoodsDialog extends StatefulWidget {
  final String customerName;
  final GoodItem? existingItem;
  final bool isLegacyMode;

  const AddGoodsDialog({
    super.key,
    required this.customerName,
    this.existingItem,
    this.isLegacyMode = false,
  });

  @override
  State<AddGoodsDialog> createState() => _AddGoodsDialogState();
}

class _AddGoodsDialogState extends State<AddGoodsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;

  late String _selectedCategory;
  late DateTime _selectedDate;

  static const List<String> categories = [
    'Grocery',
    'Snacks',
    'Beverages',
    'Dairy',
    'Vegetables',
    'Electronics',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _quantityController = TextEditingController(
      text: item != null ? (item.quantity.truncateToDouble() == item.quantity ? item.quantity.toInt().toString() : item.quantity.toString()) : '1',
    );
    _priceController = TextEditingController(
      text: item != null ? (item.unitPrice.truncateToDouble() == item.unitPrice ? item.unitPrice.toInt().toString() : item.unitPrice.toString()) : '',
    );
    _selectedCategory = item?.category ?? 'Grocery';
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = 'General';
    }
    _selectedDate = item?.date ?? (widget.isLegacyMode ? DateTime.now().subtract(const Duration(days: 1)) : DateTime.now());
  }

  double get _calculatedTotal {
    final q = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    final p = double.tryParse(_priceController.text.trim()) ?? 0.0;
    return q * p;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      } else {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            _selectedDate.hour,
            _selectedDate.minute,
          );
        });
      }
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final quantity = double.parse(_quantityController.text.trim());
      final price = double.parse(_priceController.text.trim());

      Navigator.of(context).pop({
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'quantity': quantity,
        'unitPrice': price,
        'date': _selectedDate,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: AppTheme.surface,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(22.0),
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
                        color: widget.existingItem != null
                            ? Colors.blue.withValues(alpha: 0.12)
                            : widget.isLegacyMode
                                ? Colors.purple.withValues(alpha: 0.12)
                                : AppTheme.saffronPrimary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.existingItem != null
                            ? Icons.edit_outlined
                            : widget.isLegacyMode
                                ? Icons.menu_book_outlined
                                : Icons.shopping_bag_outlined,
                        color: widget.existingItem != null
                            ? Colors.blue
                            : widget.isLegacyMode
                                ? Colors.purple
                                : AppTheme.saffronPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingItem != null
                                ? 'Edit Borrowed Record'
                                : widget.isLegacyMode
                                    ? 'Paper Book Ledger Entry'
                                    : 'Add Borrowed Goods',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            widget.existingItem != null
                                ? 'Update details (Created < 1hr ago)'
                                : widget.isLegacyMode
                                    ? 'Log historical debt for ${widget.customerName}'
                                    : 'For ${widget.customerName}',
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
                const SizedBox(height: 20),

                if (widget.isLegacyMode || widget.existingItem != null) ...[
                  // Date Selection Field
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: widget.isLegacyMode ? Colors.purple.withValues(alpha: 0.06) : AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.isLegacyMode ? Colors.purple.withValues(alpha: 0.3) : AppTheme.cardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: widget.isLegacyMode ? Colors.purple : AppTheme.saffronPrimary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.isLegacyMode ? 'Transaction Date & Time (Paper Book Date)' : 'Record Date & Time',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} at ${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit_calendar_outlined, size: 18, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Item Name Input
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    hintText: 'e.g. Milk 1L, Fortune Oil, Rice',
                    prefixIcon: Icon(Icons.shopping_basket_outlined, color: AppTheme.saffronPrimary),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter item name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category Section (Compact Chips)
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: categories.map((cat) {
                    final isSelected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppTheme.saffronPrimary.withValues(alpha: 0.15),
                      backgroundColor: AppTheme.background,
                      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.saffronDark : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppTheme.saffronPrimary : AppTheme.cardBorder,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Quantity & Unit Price Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Qty *',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          prefixIcon: Icon(Icons.numbers_outlined, color: AppTheme.textSecondary, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter Qty';
                          }
                          final d = double.tryParse(val.trim());
                          if (d == null || d <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Unit Price (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppTheme.saffronPrimary),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter Price';
                          }
                          final d = double.tryParse(val.trim());
                          if (d == null || d < 0) {
                            return 'Invalid Price';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Total Cost Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.saffronPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.saffronPrimary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Item Cost:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '₹${_calculatedTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.saffronDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

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
                      child: Text(
                        widget.existingItem != null
                            ? 'Update Item'
                            : widget.isLegacyMode
                                ? 'Save Paper Book Record'
                                : 'Add Item',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

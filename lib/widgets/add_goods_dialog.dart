import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class AddGoodsDialog extends StatefulWidget {
  final String customerName;
  final GoodItem? existingItem;
  final bool isLegacyMode;
  final Future<void> Function(Map<String, dynamic> itemData)? onSaveItem;

  const AddGoodsDialog({
    super.key,
    required this.customerName,
    this.existingItem,
    this.isLegacyMode = false,
    this.onSaveItem,
  });

  @override
  State<AddGoodsDialog> createState() => _AddGoodsDialogState();
}

class _AddGoodsDialogState extends State<AddGoodsDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  final FocusNode _nameFocusNode = FocusNode();

  late String _selectedCategory;
  late DateTime _selectedDate;

  double _dragDx = 0.0;
  bool _isSaving = false;
  int _sessionSavedCount = 0;
  String? _lastSavedName;

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
      text:
          item != null
              ? (item.quantity.truncateToDouble() == item.quantity
                  ? item.quantity.toInt().toString()
                  : item.quantity.toString())
              : '1',
    );
    _priceController = TextEditingController(
      text:
          item != null
              ? (item.unitPrice.truncateToDouble() == item.unitPrice
                  ? item.unitPrice.toInt().toString()
                  : item.unitPrice.toString())
              : '',
    );
    _selectedCategory = item?.category ?? 'Grocery';
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = 'General';
    }
    _selectedDate =
        item?.date ??
        (widget.isLegacyMode
            ? DateTime.now().subtract(const Duration(days: 1))
            : DateTime.now());
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
    _nameFocusNode.dispose();
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

  Map<String, dynamic>? _getFormData() {
    if (!_formKey.currentState!.validate()) {
      return null;
    }
    final quantity = double.parse(_quantityController.text.trim());
    final price = double.parse(_priceController.text.trim());

    return {
      'name': _nameController.text.trim(),
      'category': _selectedCategory,
      'quantity': quantity,
      'unitPrice': price,
      'date': _selectedDate,
    };
  }

  Future<void> _saveAndAddNext() async {
    final data = _getFormData();
    if (data == null) {
      // Invalid form -> bounce drag back
      setState(() {
        _dragDx = 0.0;
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // Perform save
    if (widget.onSaveItem != null) {
      await widget.onSaveItem!(data);
    }

    if (!mounted) return;

    // Animate card swipe out left
    setState(() {
      _dragDx = -400.0;
    });
    await Future.delayed(const Duration(milliseconds: 180));

    if (!mounted) return;

    // Reset form fields
    _nameController.clear();
    _quantityController.text = '1';
    _priceController.clear();

    setState(() {
      _sessionSavedCount++;
      _lastSavedName = data['name'];
      _dragDx = 300.0; // Position off-screen right for spring-in
      _isSaving = false;
    });

    // Spring card back into center
    await Future.delayed(const Duration(milliseconds: 30));
    if (mounted) {
      setState(() {
        _dragDx = 0.0;
      });
      _nameFocusNode.requestFocus();
    }
  }

  void _submitFinal() async {
    // If form has text filled, save it first
    final hasText = _nameController.text.trim().isNotEmpty ||
        _priceController.text.trim().isNotEmpty;

    if (hasText) {
      final data = _getFormData();
      if (data == null) return;

      if (widget.onSaveItem != null) {
        await widget.onSaveItem!(data);
        if (mounted) {
          Navigator.of(context).pop({'savedCount': _sessionSavedCount + 1});
        }
      } else {
        Navigator.of(context).pop(data);
      }
    } else {
      if (_sessionSavedCount > 0) {
        Navigator.of(context).pop({'savedCount': _sessionSavedCount});
      } else {
        Navigator.of(context).pop(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.existingItem != null;
    final isSwipingLeft = _dragDx < -20;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (isEditMode || _isSaving) return;
          setState(() {
            _dragDx += details.delta.dx;
            if (_dragDx > 25) _dragDx = 25; // Rubberband right
          });
        },
        onHorizontalDragEnd: (details) {
          if (isEditMode || _isSaving) return;
          if (_dragDx < -75 || details.velocity.pixelsPerSecond.dx < -250) {
            _saveAndAddNext();
          } else {
            setState(() {
              _dragDx = 0.0;
            });
          }
        },
        child: AnimatedContainer(
          duration: _dragDx == 0.0 || _dragDx == -400.0 || _dragDx == 300.0
              ? const Duration(milliseconds: 220)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(_dragDx, 0, 0)
            ..rotateZ(_dragDx * 0.0004),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSwipingLeft
                    ? AppTheme.saffronPrimary
                    : AppTheme.cardBorder,
                width: isSwipingLeft ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSwipingLeft
                      ? AppTheme.saffronPrimary.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.15),
                  blurRadius: isSwipingLeft ? 20 : 12,
                  spreadRadius: isSwipingLeft ? 2 : 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Session Saved Counter Banner
                          if (_sessionSavedCount > 0 && _lastSavedName != null) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.paidBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.paidText.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.paidText,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Saved "$_lastSavedName"! ($_sessionSavedCount item${_sessionSavedCount > 1 ? 's' : ''} added in session)',
                                      style: const TextStyle(
                                        color: AppTheme.paidText,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isEditMode
                                      ? Colors.blue.withValues(alpha: 0.12)
                                      : widget.isLegacyMode
                                          ? Colors.purple.withValues(alpha: 0.12)
                                          : AppTheme.saffronPrimary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isEditMode
                                      ? Icons.edit_outlined
                                      : widget.isLegacyMode
                                          ? Icons.menu_book_outlined
                                          : Icons.shopping_bag_outlined,
                                  color: isEditMode
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
                                      isEditMode
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
                                      isEditMode
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
                          const SizedBox(height: 14),

                          // Swipe Left Visual Cue Banner
                          if (!isEditMode) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.saffronPrimary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.saffronPrimary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.swipe_left_rounded,
                                    size: 18,
                                    color: AppTheme.saffronDark,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Swipe Left 👈 to Save & Add Next item',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.saffronDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          if (widget.isLegacyMode || isEditMode) ...[
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
                            focusNode: _nameFocusNode,
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

                          // Action Buttons
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(_sessionSavedCount > 0 ? true : null);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.textSecondary,
                                ),
                                child: Text(_sessionSavedCount > 0 ? 'Done' : 'Cancel'),
                              ),
                              const Spacer(),
                              if (!isEditMode) ...[
                                OutlinedButton.icon(
                                  onPressed: _saveAndAddNext,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.saffronDark,
                                    side: const BorderSide(color: AppTheme.saffronPrimary),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  icon: const Icon(Icons.swipe_left_rounded, size: 18),
                                  label: const Text('Add Next 👈', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                              ],
                              ElevatedButton(
                                onPressed: _submitFinal,
                                child: Text(
                                  isEditMode
                                      ? 'Update'
                                      : _sessionSavedCount > 0
                                          ? 'Save & Done'
                                          : widget.isLegacyMode
                                              ? 'Save Record'
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

                // Tinder Swipe Overlay Tag
                if (isSwipingLeft)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.saffronPrimary.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.swipe_left_rounded,
                              color: Colors.white,
                              size: 56,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'RELEASE TO SAVE & ADD NEXT 👈',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

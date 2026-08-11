import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../services/udhar_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/add_customer_dialog.dart';
import '../widgets/add_goods_dialog.dart';
import '../widgets/animated_reminder_button.dart';
import '../widgets/record_payment_dialog.dart';
import '../widgets/security_settings_dialog.dart';
import 'customer_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UdharRepository repository;
  final AuthService authService;
  final SecurityService securityService;

  const DashboardScreen({
    super.key,
    required this.repository,
    required this.authService,
    required this.securityService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _searchQuery = '';
  String _activeFilter = 'All'; // 'All', 'Owed', 'Settled'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPeriodicBiometricPrompt();
    });
  }

  Future<void> _checkPeriodicBiometricPrompt() async {
    final shouldPrompt = await widget.securityService
        .shouldPromptBiometricSetup(gapInDays: 10);
    if (shouldPrompt && mounted) {
      // Record prompt timestamp so user isn't prompted again for another 10-15 days
      await widget.securityService.updateLastBiometricPromptTime();
      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    color: AppTheme.saffronPrimary,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enable Biometric Lock',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                'Secure your ${AppConstants.appName} data quickly with fingerprint or face recognition. Note: You will need to set up a 4-digit MPIN first if you haven\'t already.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Not Now',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    SecuritySettingsDialog.show(
                      context,
                      widget.securityService,
                    );
                  },
                  child: const Text('SETUP LOCK'),
                ),
              ],
            ),
      );
    }
  }

  void _openAddCustomerDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AddCustomerDialog(repository: widget.repository),
    );

    if (result != null) {
      try {
        final customer = await widget.repository.addCustomer(
          name: result['name']!,
          phoneNumber: result['phone'] ?? '',
          address: result['address'] ?? '',
          addedByUserId: widget.authService.currentUserId,
          addedByUserName: widget.authService.currentUserName,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Customer "${customer.name}" created successfully!',
              ),
              backgroundColor: AppTheme.saffronPrimary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e
                    .toString()
                    .replaceAll('ArgumentError: ', '')
                    .replaceAll('Exception: ', ''),
              ),
              backgroundColor: AppTheme.pendingText,
            ),
          );
        }
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
          backgroundColor: AppTheme.saffronPrimary,
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
              'Payment of ₹${result['amount']} recorded with FIFO settlement!',
            ),
            backgroundColor: AppTheme.paidText,
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
        final filteredCustomers =
            allCustomers.where((c) {
              final matchesSearch =
                  c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 64,
            titleSpacing: 16,
            title: Row(
              children: [
                // Premium Wallet Brand Icon Badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.saffronPrimary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      AppConstants.appLogoAsset,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Full Store Name Branding
                Expanded(
                  child: Text(
                    AppConstants.appName,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              // Security Shield Action Button Badge
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.saffronPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.saffronPrimary.withValues(alpha: 0.22),
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.saffronDark,
                    size: 20,
                  ),
                  tooltip: 'Security Settings',
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed:
                      () => SecuritySettingsDialog.show(
                        context,
                        widget.securityService,
                      ),
                ),
              ),
              // Sign Out Action Button Badge
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  tooltip: 'Sign Out',
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    await widget.authService.signOut();
                  },
                ),
              ),
            ],
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
                      // Logged in User Greeting Banner (Seamless integrated header)
                      AnimatedGreetingHeader(
                        userName: widget.authService.currentUserName,
                      ),
                      // Grand Pending Balance Hero Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.saffronPrimary.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 14,
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
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.15),
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
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Total Collected So Far: ₹${grandSettled.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
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
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppTheme.saffronPrimary,
                          ),
                          suffixIcon:
                              _searchQuery.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      color: AppTheme.textSecondary,
                                    ),
                                    onPressed:
                                        () => setState(() => _searchQuery = ''),
                                  )
                                  : null,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 12),

                      // Filter chips
                      Row(
                        children: [
                          _buildFilterChip(
                            'All',
                            'All (${allCustomers.length})',
                          ),
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
                            _searchQuery.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.people_outline_rounded,
                            size: 54,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No customers match "$_searchQuery"'
                                : 'No customers recorded yet.',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap "+ Add Customer" to create your first entry.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  : SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final customer = filteredCustomers[index];
                        final pending = widget.repository
                            .getCustomerPendingBalance(customer.id);
                        final totalBorrowed = widget.repository
                            .getCustomerTotalBorrowed(customer.id);
                        final hasDebt = pending > 0.001;

                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => CustomerDetailScreen(
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
                                        backgroundColor: AppTheme.saffronPrimary
                                            .withValues(alpha: 0.15),
                                        foregroundColor: AppTheme.saffronDark,
                                        radius: 22,
                                        child: Text(
                                          customer.name.isNotEmpty
                                              ? customer.name[0].toUpperCase()
                                              : 'C',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${pending.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  hasDebt
                                                      ? AppTheme.pendingText
                                                      : AppTheme.paidText,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  hasDebt
                                                      ? AppTheme.pendingBg
                                                      : AppTheme.paidBg,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              hasDebt ? 'PENDING' : 'CLEARED',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    hasDebt
                                                        ? AppTheme.pendingText
                                                        : AppTheme.paidText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(
                                    height: 1,
                                    color: AppTheme.cardBorder,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Total Items Borrowed: ₹${totalBorrowed.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMuted,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_shopping_cart,
                                              size: 20,
                                              color: AppTheme.saffronPrimary,
                                            ),
                                            tooltip: 'Add Goods',
                                            onPressed:
                                                () => _openAddGoodsDialog(
                                                  customer,
                                                ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.payment,
                                              size: 20,
                                              color: AppTheme.paidText,
                                            ),
                                            tooltip: 'Record Payment',
                                            onPressed:
                                                () => _openRecordPaymentDialog(
                                                  customer,
                                                ),
                                          ),
                                          const SizedBox(width: 4),
                                          AnimatedReminderButton(
                                            customer: customer,
                                            repository: widget.repository,
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: AppTheme.textMuted,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }, childCount: filteredCustomers.length),
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
      selectedColor: AppTheme.saffronPrimary.withValues(alpha: 0.15),
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.saffronDark : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.saffronPrimary : AppTheme.cardBorder,
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

class AnimatedGreetingHeader extends StatefulWidget {
  final String userName;

  const AnimatedGreetingHeader({super.key, required this.userName});

  @override
  State<AnimatedGreetingHeader> createState() => _AnimatedGreetingHeaderState();
}

class _AnimatedGreetingHeaderState extends State<AnimatedGreetingHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _getGreetingText() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning,';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon,';
    } else {
      return 'Good Evening,';
    }
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return Icons.wb_sunny_rounded;
    } else if (hour >= 12 && hour < 17) {
      return Icons.wb_cloudy_rounded;
    } else if (hour >= 17 && hour < 22) {
      return Icons.nights_stay_rounded;
    } else {
      return Icons.dark_mode_rounded;
    }
  }

  Color _getGreetingColor() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return const Color(0xFFFF8F00); // Morning Sun Gold
    } else if (hour >= 12 && hour < 17) {
      return const Color(0xFFE65100); // Afternoon Warm Orange
    } else if (hour >= 17 && hour < 22) {
      return const Color(0xFF5C6BC0); // Evening Indigo
    } else {
      return const Color(0xFF7E57C2); // Night Purple
    }
  }

  @override
  Widget build(BuildContext context) {
    final greetingText = _getGreetingText();
    final greetingIcon = _getGreetingIcon();
    final iconColor = _getGreetingColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 4.0, right: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$greetingText ',
                        style: GoogleFonts.dancingScript(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.saffronDark,
                        ),
                      ),
                      TextSpan(
                        text: widget.userName,
                        style: GoogleFonts.dancingScript(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RotationTransition(
                  turns: _rotationAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Icon(greetingIcon, color: iconColor, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

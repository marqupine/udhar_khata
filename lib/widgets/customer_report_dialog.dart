import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../models/models.dart';
import '../services/udhar_repository.dart';
import '../theme/app_theme.dart';

class CustomerReportDialog extends StatefulWidget {
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

  @override
  State<CustomerReportDialog> createState() => _CustomerReportDialogState();
}

class _CustomerReportDialogState extends State<CustomerReportDialog> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isSharing = false;

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

  Future<void> _shareThermalReceiptPng(double pendingBalance) async {
    setState(() => _isSharing = true);
    try {
      // Wait briefly for layout/paint to stabilize
      await Future.delayed(const Duration(milliseconds: 100));

      RenderRepaintBoundary? boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not capture receipt preview. Please try again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode receipt image to PNG format.');
      }
      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/udhar_khata_${widget.customer.id}_receipt.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      final messageText =
          'Hello ${widget.customer.name}, here is your ${AppConstants.appName} account statement receipt.\nNet Due Balance: ₹${pendingBalance.toStringAsFixed(2)}.\nBest wishes!';

      // 1. Trigger system share (shares PNG image with caption)
      try {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: messageText,
          subject: '${AppConstants.appName} Statement - ${widget.customer.name}',
        );
      } catch (shareErr) {
        debugPrint('System share plugin exception (hot reload pending rebuild): $shareErr');
      }

      // 2. Direct WhatsApp launcher fallback if phone number is present
      String cleanPhone = widget.customer.phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone'; // Default to India country code
      }

      if (cleanPhone.isNotEmpty) {
        final waUrl = Uri.parse(
          'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(messageText)}',
        );
        if (await canLaunchUrl(waUrl)) {
          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
        } else {
          // Fallback to whatsapp:// protocol if wa.me fails
          final waAppUrl = Uri.parse(
            'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(messageText)}',
          );
          if (await canLaunchUrl(waAppUrl)) {
            await launchUrl(waAppUrl, mode: LaunchMode.externalApplication);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Receipt PNG saved! Opening WhatsApp for ${widget.customer.name}...',
            ),
            backgroundColor: const Color(0xFF25D366),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sharing receipt PNG: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating reminder image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goods = widget.repository.getGoodsForCustomer(widget.customer.id);
    final totalBorrowed = widget.repository.getCustomerTotalBorrowed(
      widget.customer.id,
    );
    final totalPaid = widget.repository.getCustomerTotalPaid(
      widget.customer.id,
    );
    final pendingBalance = widget.repository.getCustomerPendingBalance(
      widget.customer.id,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
          maxWidth: 550,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: AppTheme.saffronDark,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Supermart Thermal Bill',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Scrollable Thermal Bill View (Captured in RepaintBoundary)
            Expanded(
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCFCF9), // Thermal Paper Tint
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E2DC)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Store Branding Badge
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.saffronPrimary,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              AppConstants.appLogoAsset,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          AppConstants.appName.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '*** ACCOUNT STATEMENT RECEIPT ***',
                          style: GoogleFonts.courierPrime(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Dotted Line Divider
                        const Text(
                          '------------------------------------------------------------------',
                          style: TextStyle(
                            color: Colors.black38,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                        const SizedBox(height: 8),

                        // Customer & Receipt Meta Info
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMetaRow(
                                'Customer:',
                                widget.customer.name,
                                isBold: true,
                              ),
                              if (widget.customer.phoneNumber.isNotEmpty)
                                _buildMetaRow(
                                  'Phone:',
                                  widget.customer.phoneNumber,
                                ),
                              if (widget.customer.address.isNotEmpty)
                                _buildMetaRow(
                                  'Address:',
                                  widget.customer.address,
                                ),
                              _buildMetaRow(
                                'Date & Time:',
                                _formatDateTime(DateTime.now()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        const Text(
                          '------------------------------------------------------------------',
                          style: TextStyle(
                            color: Colors.black38,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                        const SizedBox(height: 8),

                        // Table Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ITEM DETAILS',
                              style: GoogleFonts.courierPrime(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'TOTAL (₹)',
                              style: GoogleFonts.courierPrime(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Itemized Borrowed Goods List
                        if (goods.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No borrowed goods logged.',
                              style: GoogleFonts.courierPrime(
                                color: Colors.black54,
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: goods.length,
                            separatorBuilder:
                                (ctx, i) => const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
                                    style: TextStyle(
                                      color: Colors.black12,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                            itemBuilder: (context, index) {
                              final item = goods[index];
                              final qtyStr = item.quantity.toStringAsFixed(
                                item.quantity.truncateToDouble() ==
                                        item.quantity
                                    ? 0
                                    : 1,
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${index + 1}. ${item.name}',
                                          style: GoogleFonts.courierPrime(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '₹${item.totalPrice.toStringAsFixed(2)}',
                                        style: GoogleFonts.courierPrime(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '   Borrow Time: ${_formatDateTime(item.date)}',
                                    style: GoogleFonts.courierPrime(
                                      fontSize: 11,
                                      color: Colors.black54,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  Text(
                                    '   $qtyStr qty @ ₹${item.unitPrice.toStringAsFixed(2)} | Status: ${item.statusLabel}',
                                    style: GoogleFonts.courierPrime(
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (item.amountPaid > 0.001)
                                    Text(
                                      '   Paid: ₹${item.amountPaid.toStringAsFixed(2)} | Due: ₹${item.remainingAmount.toStringAsFixed(2)}',
                                      style: GoogleFonts.courierPrime(
                                        fontSize: 11,
                                        color: Colors.black87,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),

                        const SizedBox(height: 10),
                        const Text(
                          '==================================================================',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                        const SizedBox(height: 8),

                        // Financial Totals Summary
                        _buildSummaryRow(
                          'TOTAL BORROWED:',
                          '₹${totalBorrowed.toStringAsFixed(2)}',
                        ),
                        _buildSummaryRow(
                          'TOTAL PAID:',
                          '₹${totalPaid.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                pendingBalance > 0.001
                                    ? AppTheme.pendingBg
                                    : AppTheme.paidBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  pendingBalance > 0.001
                                      ? AppTheme.pendingText
                                      : AppTheme.paidText,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'NET DUE BALANCE:',
                                style: GoogleFonts.courierPrime(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color:
                                      pendingBalance > 0.001
                                          ? AppTheme.pendingText
                                          : AppTheme.paidText,
                                ),
                              ),
                              Text(
                                '₹${pendingBalance.toStringAsFixed(2)}',
                                style: GoogleFonts.courierPrime(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color:
                                      pendingBalance > 0.001
                                          ? AppTheme.pendingText
                                          : AppTheme.paidText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        const Text(
                          '------------------------------------------------------------------',
                          style: TextStyle(
                            color: Colors.black38,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                        const SizedBox(height: 10),

                        // Best Wishes Footer Note
                        Text(
                          '🌟 Best wishes! Thank you for shopping with us.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Powered by ${AppConstants.appName} Smart Ledger',
                          style: GoogleFonts.courierPrime(
                            fontSize: 10,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Single WhatsApp Reminder Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                icon:
                    _isSharing
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _isSharing
                      ? 'Generating Receipt PNG...'
                      : 'Send Reminder on WhatsApp',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed:
                    _isSharing
                        ? null
                        : () => _shareThermalReceiptPng(pendingBalance),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.courierPrime(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.courierPrime(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.courierPrime(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.courierPrime(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

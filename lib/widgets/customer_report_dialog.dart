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
      builder:
          (context) =>
              CustomerReportDialog(customer: customer, repository: repository),
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

  Future<void> _shareConsolidatedReportPng(
    double totalBorrowed,
    double totalPaid,
    double pendingBalance,
  ) async {
    setState(() => _isSharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      RenderRepaintBoundary? boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not capture statement preview. Please try again.'),
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
        throw Exception('Failed to encode report image to PNG format.');
      }
      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/udhar_khata_${widget.customer.id}_consolidated_report.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      final messageText =
          'Hello ${widget.customer.name}, here is your consolidated account ledger statement from ${AppConstants.appName}.\nTotal Borrowed: ₹${totalBorrowed.toStringAsFixed(2)}\nTotal Paid: ₹${totalPaid.toStringAsFixed(2)}\nNet Balance: ₹${pendingBalance.toStringAsFixed(2)}.\nThank you!';

      try {
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(filePath)],
          text: messageText,
          subject: '${AppConstants.appName} Consolidated Statement - ${widget.customer.name}',
        );
      } catch (shareErr) {
        debugPrint('System share plugin exception: $shareErr');
      }

      String cleanPhone = widget.customer.phoneNumber.replaceAll(
        RegExp(r'\D'),
        '',
      );
      if (cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone';
      }

      if (cleanPhone.isNotEmpty) {
        final waUrl = Uri.parse(
          'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(messageText)}',
        );
        if (await canLaunchUrl(waUrl)) {
          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
        } else {
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
              'Consolidated Report saved! Opening WhatsApp for ${widget.customer.name}...',
            ),
            backgroundColor: AppTheme.saffronPrimary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sharing report PNG: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report image: $e'),
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
    final payments = widget.repository.getPaymentsForCustomer(widget.customer.id);
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
          maxWidth: 580,
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
                      Icons.assessment_outlined,
                      color: AppTheme.saffronDark,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Consolidated Report',
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

            // Scrollable Consolidated Statement Document View
            Expanded(
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCFCF9), // Ledger Paper Background
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
                        // Store Logo Badge
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
                          '*** CONSOLIDATED CUSTOMER STATEMENT ***',
                          style: GoogleFonts.courierPrime(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.saffronDark,
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
                        const SizedBox(height: 8),

                        // Customer Metadata
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
                                'Statement Date:',
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

                        // Section 1: Borrowed Goods (Paid & Unpaid)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '1. BORROWED GOODS LOG (PAID & UNPAID)',
                            style: GoogleFonts.courierPrime(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        if (goods.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No borrowed goods recorded.',
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
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '₹${item.totalPrice.toStringAsFixed(2)}',
                                        style: GoogleFonts.courierPrime(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '   Date: ${_formatDateTime(item.date)}',
                                        style: GoogleFonts.courierPrime(
                                          fontSize: 10,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              item.isPaid
                                                  ? AppTheme.paidBg
                                                  : item.isPartiallyPaid
                                                  ? AppTheme.partialBg
                                                  : AppTheme.pendingBg,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          item.statusLabel,
                                          style: GoogleFonts.courierPrime(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                item.isPaid
                                                    ? AppTheme.paidText
                                                    : item.isPartiallyPaid
                                                    ? AppTheme.partialText
                                                    : AppTheme.pendingText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '   $qtyStr qty @ ₹${item.unitPrice.toStringAsFixed(2)} | Paid: ₹${item.amountPaid.toStringAsFixed(2)} | Due: ₹${item.remainingAmount.toStringAsFixed(2)}',
                                    style: GoogleFonts.courierPrime(
                                      fontSize: 10,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              );
                            },
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
                        const SizedBox(height: 8),

                        // Section 2: Payment Receipts History
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '2. PAYMENT RECEIPTS HISTORY',
                            style: GoogleFonts.courierPrime(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.paidText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        if (payments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No payment receipts recorded.',
                              style: GoogleFonts.courierPrime(
                                color: Colors.black54,
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: payments.length,
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
                              final pay = payments[index];
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${index + 1}. Payment Received (${_formatDateTime(pay.date)})',
                                        style: GoogleFonts.courierPrime(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.paidText,
                                        ),
                                      ),
                                      if (pay.note.isNotEmpty)
                                        Text(
                                          '   Note: ${pay.note}',
                                          style: GoogleFonts.courierPrime(
                                            fontSize: 10,
                                            color: Colors.black54,
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    '₹${pay.amountPaid.toStringAsFixed(2)}',
                                    style: GoogleFonts.courierPrime(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.paidText,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                        const SizedBox(height: 12),
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

                        // Account Financial Metrics Summary
                        _buildSummaryRow(
                          'TOTAL BORROWED GOODS:',
                          '₹${totalBorrowed.toStringAsFixed(2)}',
                        ),
                        _buildSummaryRow(
                          'TOTAL PAYMENTS RECEIVED:',
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
                                'NET PENDING BALANCE:',
                                style: GoogleFonts.courierPrime(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                                  fontSize: 17,
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

                        Text(
                          '🌟 Thank you for doing business with us!',
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

            // Share Consolidated Report Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.saffronPrimary,
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
                        : const Icon(Icons.share_rounded, size: 20),
                label: Text(
                  _isSharing
                      ? 'Generating Consolidated Report...'
                      : 'Share Consolidated Statement',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed:
                    _isSharing
                        ? null
                        : () => _shareConsolidatedReportPng(
                          totalBorrowed,
                          totalPaid,
                          pendingBalance,
                        ),
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
            width: 105,
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
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.courierPrime(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

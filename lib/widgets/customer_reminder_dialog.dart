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

class CustomerReminderDialog extends StatefulWidget {
  final Customer customer;
  final UdharRepository repository;

  const CustomerReminderDialog({
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
              CustomerReminderDialog(customer: customer, repository: repository),
    );
  }

  @override
  State<CustomerReminderDialog> createState() => _CustomerReminderDialogState();
}

class _CustomerReminderDialogState extends State<CustomerReminderDialog> {
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
      final filePath =
          '${tempDir.path}/udhar_khata_${widget.customer.id}_dues_reminder.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      final messageText =
          'Hello ${widget.customer.name}, this is a gentle reminder regarding your pending balance on ${AppConstants.appName}.\nTotal Outstanding Dues: ₹${pendingBalance.toStringAsFixed(2)}.\nPlease arrange for payment at your earliest convenience. Thank you!';

      try {
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(filePath)],
          text: messageText,
          subject: '${AppConstants.appName} Dues Reminder - ${widget.customer.name}',
        );
      } catch (shareErr) {
        debugPrint('System share plugin error: $shareErr');
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
              'Reminder PNG saved! Opening WhatsApp for ${widget.customer.name}...',
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
    final allGoods = widget.repository.getGoodsForCustomer(widget.customer.id);
    // ONLY unpaid or partially paid goods for reminder bill
    final unpaidGoods = allGoods.where((g) => !g.isPaid).toList();
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
                      Icons.rocket_launch_rounded,
                      color: AppTheme.pendingText,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dues Reminder Bill',
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

            // Scrollable Thermal Paper Dues Bill View
            Expanded(
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDF5), // Warm Thermal Paper
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8E2CE)),
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
                        // Branding Circle
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.pendingText,
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
                          '*** OUTSTANDING DUES REMINDER BILL ***',
                          style: GoogleFonts.courierPrime(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.pendingText,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Dotted Divider
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

                        // Meta Info
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

                        // Section Title: UNPAID BORROWED GOODS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'UNPAID ITEM DETAILS',
                              style: GoogleFonts.courierPrime(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.pendingText,
                              ),
                            ),
                            Text(
                              'DUE AMOUNT (₹)',
                              style: GoogleFonts.courierPrime(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.pendingText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Itemized List - UNPAID ITEMS ONLY
                        if (unpaidGoods.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No pending dues! All borrowed goods are paid.',
                              style: GoogleFonts.courierPrime(
                                color: AppTheme.paidText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: unpaidGoods.length,
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
                              final item = unpaidGoods[index];
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
                                        '₹${item.remainingAmount.toStringAsFixed(2)}',
                                        style: GoogleFonts.courierPrime(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppTheme.pendingText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '   Date: ${_formatDateTime(item.date)}',
                                    style: GoogleFonts.courierPrime(
                                      fontSize: 11,
                                      color: Colors.black54,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  Text(
                                    '   $qtyStr qty @ ₹${item.unitPrice.toStringAsFixed(2)} | Total: ₹${item.totalPrice.toStringAsFixed(2)}',
                                    style: GoogleFonts.courierPrime(
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (item.amountPaid > 0.001)
                                    Text(
                                      '   Already Paid: ₹${item.amountPaid.toStringAsFixed(2)} | Balance Due: ₹${item.remainingAmount.toStringAsFixed(2)}',
                                      style: GoogleFonts.courierPrime(
                                        fontSize: 11,
                                        color: AppTheme.pendingText,
                                        fontWeight: FontWeight.bold,
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

                        // Net Due Balance Container
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.pendingBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.pendingText,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL OUTSTANDING DUES:',
                                style: GoogleFonts.courierPrime(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.pendingText,
                                ),
                              ),
                              Text(
                                '₹${pendingBalance.toStringAsFixed(2)}',
                                style: GoogleFonts.courierPrime(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: AppTheme.pendingText,
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
                          '⚠️ Kindly settle your pending dues at the earliest.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.pendingText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Generated via ${AppConstants.appName} Smart Ledger',
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

            // Send Reminder Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
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
                      ? 'Preparing Reminder PNG...'
                      : 'Send Dues Reminder on WhatsApp',
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
}

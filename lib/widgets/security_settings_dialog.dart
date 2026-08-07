import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';

class SecuritySettingsDialog extends StatefulWidget {
  final SecurityService securityService;

  const SecuritySettingsDialog({super.key, required this.securityService});

  static Future<void> show(BuildContext context, SecurityService securityService) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SecuritySettingsDialog(securityService: securityService),
    );
  }

  @override
  State<SecuritySettingsDialog> createState() => _SecuritySettingsDialogState();
}

class _SecuritySettingsDialogState extends State<SecuritySettingsDialog> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isSettingPinMode = false;
  bool _hardwareBiometricAvailable = false;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final avail = await widget.securityService.isBiometricHardwareAvailable();
    if (mounted) {
      setState(() {
        _hardwareBiometricAvailable = avail;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _saveNewPin() async {
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _pinError = 'MPIN must be exactly 4 digits');
      return;
    }

    if (pin != confirmPin) {
      setState(() => _pinError = 'MPINs do not match');
      return;
    }

    await widget.securityService.setMpin(pin);

    if (mounted) {
      setState(() {
        _isSettingPinMode = false;
        _pinError = null;
        _pinController.clear();
        _confirmPinController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('4-Digit MPIN set successfully!'),
          backgroundColor: AppTheme.paidText,
        ),
      );
    }
  }

  Future<void> _handleBiometricToggle(bool value) async {
    if (value && !widget.securityService.hasMpin) {
      // Show error snackbar: Biometrics cannot be setup without MPIN
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric authentication cannot be setup without setting up an MPIN first.'),
          backgroundColor: AppTheme.saffronDark,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (value) {
      final authenticated = await widget.securityService.authenticateWithBiometrics(
        reason: 'Authenticate to enable Biometric lock',
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication failed or cancelled.'),
              backgroundColor: AppTheme.pendingText,
            ),
          );
        }
        return;
      }
    }

    await widget.securityService.setBiometricEnabled(value);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleRemoveMpin() async {
    await widget.securityService.clearMpin();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MPIN and Biometric security removed.'),
          backgroundColor: AppTheme.saffronDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMpin = widget.securityService.hasMpin;
    final isBioEnabled = widget.securityService.isBiometricEnabled;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handlebar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.partialBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.security_rounded, color: AppTheme.saffronDark),
                ),
                const SizedBox(width: 12),
                const Text(
                  'App Security & Lock',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_isSettingPinMode) ...[
              // Setup New MPIN Form
              const Text(
                'Create 4-Digit MPIN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              if (_pinError != null) ...[
                Text(
                  _pinError!,
                  style: const TextStyle(color: AppTheme.pendingText, fontSize: 13),
                ),
                const SizedBox(height: 8),
              ],

              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Enter 4-Digit MPIN',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm 4-Digit MPIN',
                  prefixIcon: Icon(Icons.lock_clock_outlined),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isSettingPinMode = false;
                          _pinError = null;
                        });
                      },
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveNewPin,
                      child: const Text('SAVE PIN'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Security Settings Status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    // MPIN Tile
                    Row(
                      children: [
                        const Icon(Icons.pin_rounded, color: AppTheme.saffronPrimary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '4-Digit MPIN Lock',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                hasMpin ? 'MPIN is active' : 'Not configured (Optional)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: hasMpin ? AppTheme.paidText : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasMpin) ...[
                          TextButton(
                            onPressed: () {
                              setState(() => _isSettingPinMode = true);
                            },
                            child: const Text('Change'),
                          ),
                        ] else ...[
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _isSettingPinMode = true);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: const Text('Set MPIN', style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ],
                    ),
                    const Divider(height: 24),

                    // Biometrics Tile
                    Row(
                      children: [
                        const Icon(Icons.fingerprint_rounded, color: AppTheme.saffronPrimary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Biometric Lock',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                !_hardwareBiometricAvailable
                                    ? 'Hardware not supported'
                                    : !hasMpin
                                        ? 'Requires MPIN setup first'
                                        : isBioEnabled
                                            ? 'Enabled'
                                            : 'Disabled',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isBioEnabled ? AppTheme.paidText : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isBioEnabled,
                          activeThumbColor: AppTheme.saffronPrimary,
                          onChanged: _hardwareBiometricAvailable ? _handleBiometricToggle : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (hasMpin) ...[
                OutlinedButton.icon(
                  onPressed: _handleRemoveMpin,
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.pendingText),
                  label: const Text('Remove MPIN & Lock', style: TextStyle(color: AppTheme.pendingText)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.pendingText),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
  bool _isSettingPinMode = false;
  int _pinSetupStep = 1; // 1 = Create, 2 = Confirm
  String _firstEnteredPin = '';
  String _currentStepPin = '';
  String? _pinError;

  bool _hardwareBiometricAvailable = false;

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

  void _startPinSetup() {
    setState(() {
      _isSettingPinMode = true;
      _pinSetupStep = 1;
      _firstEnteredPin = '';
      _currentStepPin = '';
      _pinError = null;
    });
  }

  void _cancelPinSetup() {
    setState(() {
      _isSettingPinMode = false;
      _pinSetupStep = 1;
      _firstEnteredPin = '';
      _currentStepPin = '';
      _pinError = null;
    });
  }

  void _onDigitPressed(String digit) {
    if (_currentStepPin.length >= 4) return;

    setState(() {
      _pinError = null;
      _currentStepPin += digit;
    });

    if (_currentStepPin.length == 4) {
      if (_pinSetupStep == 1) {
        _firstEnteredPin = _currentStepPin;
        setState(() {
          _pinSetupStep = 2;
          _currentStepPin = '';
        });
      } else if (_pinSetupStep == 2) {
        if (_currentStepPin == _firstEnteredPin) {
          _savePinAndComplete(_currentStepPin);
        } else {
          setState(() {
            _pinError = 'MPINs did not match. Please try again.';
            _pinSetupStep = 1;
            _firstEnteredPin = '';
            _currentStepPin = '';
          });
        }
      }
    }
  }

  void _onBackspacePressed() {
    if (_currentStepPin.isNotEmpty) {
      setState(() {
        _pinError = null;
        _currentStepPin = _currentStepPin.substring(0, _currentStepPin.length - 1);
      });
    }
  }

  Future<void> _savePinAndComplete(String pin) async {
    await widget.securityService.setMpin(pin);

    if (mounted) {
      setState(() {
        _isSettingPinMode = false;
        _pinSetupStep = 1;
        _firstEnteredPin = '';
        _currentStepPin = '';
        _pinError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('4-Digit Security MPIN set successfully!'),
          backgroundColor: AppTheme.paidText,
        ),
      );
    }
  }

  Future<void> _handleBiometricToggle(bool value) async {
    if (value && !widget.securityService.hasMpin) {
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
        requireEnabledCheck: false,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handlebar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (_isSettingPinMode) ...[
              // --- MODERN INTERACTIVE KEYPAD PIN SETUP ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                    onPressed: _cancelPinSetup,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.saffronPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Step $_pinSetupStep of 2',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.saffronDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Step Header Title
              Center(
                child: Text(
                  _pinSetupStep == 1 ? 'Create 4-Digit Security MPIN' : 'Confirm Your 4-Digit MPIN',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              Center(
                child: Text(
                  _pinError ??
                      (_pinSetupStep == 1
                          ? 'Enter 4 digits to secure your app'
                          : 'Re-enter the same 4 digits to confirm'),
                  style: TextStyle(
                    fontSize: 13,
                    color: _pinError != null ? AppTheme.pendingText : AppTheme.textSecondary,
                    fontWeight: _pinError != null ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Animated PIN Dot Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _currentStepPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? (_pinError != null ? AppTheme.pendingText : AppTheme.saffronPrimary)
                          : Colors.transparent,
                      border: Border.all(
                        color: isFilled
                            ? (_pinError != null ? AppTheme.pendingText : AppTheme.saffronPrimary)
                            : AppTheme.darkGold,
                        width: 2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: (_pinError != null
                                        ? AppTheme.pendingText
                                        : AppTheme.saffronPrimary)
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Numpad Keypad Grid
              Center(
                child: SizedBox(
                  width: 280,
                  child: Column(
                    children: [
                      _buildSetupNumpadRow(['1', '2', '3']),
                      const SizedBox(height: 12),
                      _buildSetupNumpadRow(['4', '5', '6']),
                      const SizedBox(height: 12),
                      _buildSetupNumpadRow(['7', '8', '9']),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const SizedBox(width: 60, height: 60),
                          _buildSetupNumpadButton('0'),
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: IconButton(
                              onPressed: _onBackspacePressed,
                              icon: const Icon(
                                Icons.backspace_outlined,
                                size: 22,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              // --- DASHBOARD STATUS CARDS ---
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
              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(18),
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
                            onPressed: _startPinSetup,
                            child: const Text('Change'),
                          ),
                        ] else ...[
                          ElevatedButton(
                            onPressed: _startPinSetup,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              const SizedBox(height: 18),

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
                const SizedBox(height: 10),
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

  Widget _buildSetupNumpadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildSetupNumpadButton(d)).toList(),
    );
  }

  Widget _buildSetupNumpadButton(String digit) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _onDigitPressed(digit),
        borderRadius: BorderRadius.circular(30),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

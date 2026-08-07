import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';

class MpinScreen extends StatefulWidget {
  final SecurityService securityService;
  final VoidCallback onUnlocked;

  const MpinScreen({
    super.key,
    required this.securityService,
    required this.onUnlocked,
  });

  @override
  State<MpinScreen> createState() => _MpinScreenState();
}

class _MpinScreenState extends State<MpinScreen> {
  String _enteredPin = '';
  String? _errorMessage;
  bool _isAuthenticatingBiometrics = false;

  @override
  void initState() {
    super.initState();
    // Attempt biometric unlock automatically if enabled
    if (widget.securityService.isBiometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerBiometricAuth();
      });
    }
  }

  Future<void> _triggerBiometricAuth() async {
    if (_isAuthenticatingBiometrics) return;
    setState(() => _isAuthenticatingBiometrics = true);

    final success = await widget.securityService.authenticateWithBiometrics(
      reason: 'Scan fingerprint / face to unlock ${AppConstants.appName}',
    );

    if (mounted) {
      setState(() => _isAuthenticatingBiometrics = false);
      if (success) {
        widget.onUnlocked();
      }
    }
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= 4) return;

    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _verifyPin() {
    if (widget.securityService.verifyMpin(_enteredPin)) {
      widget.onUnlocked();
    } else {
      setState(() {
        _errorMessage = 'Incorrect 4-digit MPIN. Try again.';
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBiometricBtn = widget.securityService.isBiometricEnabled;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFBF5),
              Color(0xFFFFF6E5),
              Color(0xFFFFECCC),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              // Icon Header
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.saffronPrimary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Enter 4-Digit MPIN',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                _errorMessage ?? 'Enter your security code to unlock app',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: _errorMessage != null ? FontWeight.w600 : FontWeight.w400,
                  color: _errorMessage != null ? AppTheme.pendingText : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // PIN Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? AppTheme.saffronPrimary : Colors.transparent,
                      border: Border.all(
                        color: isFilled ? AppTheme.saffronPrimary : AppTheme.darkGold,
                        width: 2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: AppTheme.saffronPrimary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                  );
                }),
              ),
              const Spacer(),

              // Custom Keypad
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                child: Column(
                  children: [
                    _buildNumpadRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildNumpadRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildNumpadRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Biometric trigger button (or empty space)
                        SizedBox(
                          width: 70,
                          height: 70,
                          child: showBiometricBtn
                              ? IconButton(
                                  onPressed: _triggerBiometricAuth,
                                  icon: const Icon(
                                    Icons.fingerprint_rounded,
                                    size: 36,
                                    color: AppTheme.saffronPrimary,
                                  ),
                                )
                              : null,
                        ),

                        // Zero Button
                        _buildNumpadButton('0'),

                        // Backspace Button
                        SizedBox(
                          width: 70,
                          height: 70,
                          child: IconButton(
                            onPressed: _onBackspacePressed,
                            icon: const Icon(
                              Icons.backspace_outlined,
                              size: 26,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildNumpadButton(d)).toList(),
    );
  }

  Widget _buildNumpadButton(String digit) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _onDigitPressed(digit),
        borderRadius: BorderRadius.circular(35),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

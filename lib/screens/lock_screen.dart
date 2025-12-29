import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _isAuthenticating = false;
  String _biometricType = 'Biometrics';

  @override
  void initState() {
    super.initState();
    _loadBiometricType();
    _authenticate();
  }

  Future<void> _loadBiometricType() async {
    final type = await AuthService.getBiometricTypeName();
    setState(() => _biometricType = type);
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    final success = await AuthService.authenticate(
      reason: 'Unlock Bolt21 wallet',
    );

    setState(() => _isAuthenticating = false);

    if (success) {
      widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),

              // Logo
              Image.asset(
                'assets/images/logo.png',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 16),
              const Text(
                'Wallet is locked',
                style: TextStyle(color: Bolt21Theme.textSecondary),
              ),

              const Spacer(),

              // Unlock button
              if (_isAuthenticating)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Bolt21Theme.orange),
                    SizedBox(height: 16),
                    Text(
                      'Authenticating...',
                      style: TextStyle(color: Bolt21Theme.textSecondary),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    // Biometric icon
                    GestureDetector(
                      onTap: _authenticate,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Bolt21Theme.darkCard,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Bolt21Theme.orange,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _biometricType == 'Face ID'
                              ? Icons.face
                              : Icons.fingerprint,
                          size: 40,
                          color: Bolt21Theme.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap to unlock with $_biometricType',
                      style: const TextStyle(color: Bolt21Theme.textSecondary),
                    ),
                  ],
                ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

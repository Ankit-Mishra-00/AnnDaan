import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_screen.dart';
import '../../theme/app_theme.dart'; // Ensure this points to your new theme file

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isEmailMode = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _inputController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEmailMode) {
        // Email & Password Handshake Flow
        final AuthResponse response = await _supabase.auth.signInWithPassword(
          email: _inputController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // ✨ FIXED: Check mounted barrier before managing screen pops across the async gap
        if (!mounted) return;

        if (response.session != null) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      } else {
        // Phone Authentication OTP Flow
        String formattedPhone = _inputController.text.trim();
        if (!formattedPhone.startsWith('+')) {
          formattedPhone = '+91$formattedPhone';
        }

        await _supabase.auth.signInWithOtp(phone: formattedPhone);

        // ✨ FIXED: Check mounted barrier before showing the dialog across the async gap
        if (!mounted) return;
        _showOtpDialog(formattedPhone);
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: AppTheme.destructiveRed),
        );
      }
    } on SocketException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Network lookup failed. Check your connection or cold boot your emulator! 🔌"),
            backgroundColor: AppTheme.destructiveRed,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Network lookup failed. Check your connection or cold boot your emulator! 🔌"),
            backgroundColor: AppTheme.destructiveRed,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Authentication Error: ${e.toString()}"), backgroundColor: AppTheme.destructiveRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOtpDialog(String phoneNumber) {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Enter OTP",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark),
        ),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration("6-digit code sent via SMS", Icons.message_outlined),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryEmerald,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              try {
                await _supabase.auth.verifyOTP(
                  phone: phoneNumber,
                  token: otpController.text.trim(),
                  type: OtpType.sms,
                );

                // ✨ FIXED: Check the explicit dialog layout lifecycle context across the async gap
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext); // Safely dismiss the OTP Dialog Box

                // ✨ FIXED: Check the main screen structure state lifecycle before changing roots
                if (!mounted) return;
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop(); // Dismiss the Login Screen baseline frame
                }
              } on AuthException catch (err) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text("Invalid OTP: ${err.message}"), backgroundColor: AppTheme.destructiveRed),
                );
              } on SocketException catch (_) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text("Network timeout. Could not verify OTP code."), backgroundColor: AppTheme.destructiveRed),
                );
              } catch (e) {
                if (!dialogContext.mounted) return;
                if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text("Network timeout. Could not verify OTP code."), backgroundColor: AppTheme.destructiveRed),
                  );
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text("Verification error: $e"), backgroundColor: AppTheme.destructiveRed),
                  );
                }
              }
            },
            child: const Text("Verify", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.bgGradientStart, AppTheme.bgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_person_outlined, size: 40, color: AppTheme.primaryEmerald),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Welcome Back",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textDark, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Login via ${_isEmailMode ? 'Email' : 'Phone'} to continue your impact.",
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [AppTheme.premiumShadow],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel(_isEmailMode ? "Email Address" : "Phone Number"),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!_isEmailMode) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgGradientStart,
                                    border: Border.all(color: Colors.black12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text("+91", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: TextFormField(
                                  controller: _inputController,
                                  keyboardType: _isEmailMode ? TextInputType.emailAddress : TextInputType.phone,
                                  decoration: _inputDecoration(
                                    _isEmailMode ? "name@example.com" : "Enter 10-digit number",
                                    _isEmailMode ? Icons.mail_outline : Icons.phone_android,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return "This field is required";
                                    if (_isEmailMode && !val.contains('@')) return "Enter a valid email address";
                                    if (!_isEmailMode && val.length < 10) return "Enter a valid mobile number";
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          if (_isEmailMode) ...[
                            const SizedBox(height: 20),
                            _buildLabel("Password"),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: _inputDecoration("Enter your password", Icons.lock_outline),
                              validator: (val) => val == null || val.length < 6 ? "Password must be at least 6 characters" : null,
                            ),
                          ],

                          const SizedBox(height: 32),

                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryEmerald.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryEmerald,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                                    : const Text("Access Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          const Center(
                            child: Text("or alternative options", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                          ),
                          const SizedBox(height: 20),

                          _socialButton(
                            _isEmailMode ? "Switch to Phone Login" : "Switch to Email Login",
                            _isEmailMode ? Icons.phone_android_rounded : Icons.email_outlined,
                                () {
                              setState(() {
                                _isEmailMode = !_isEmailMode;
                                _formKey.currentState?.reset();
                                _inputController.clear();
                                _passwordController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? ", style: TextStyle(fontSize: 15, color: AppTheme.textMuted)),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignUpScreen()),
                          );
                        },
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMuted)),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
      filled: true,
      fillColor: AppTheme.bgGradientStart,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryEmerald, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.destructiveRed)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.destructiveRed, width: 1.5)),
    );
  }

  Widget _socialButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: AppTheme.textDark, size: 20),
        label: Text(label, style: const TextStyle(color: AppTheme.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.black12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppTheme.bgGradientStart,
          elevation: 0,
        ),
      ),
    );
  }
}
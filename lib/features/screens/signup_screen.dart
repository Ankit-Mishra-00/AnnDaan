import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth_gate.dart';
import '../../theme/app_theme.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String _selectedRole = 'receiver';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String formattedPhone = _phoneController.text.trim();
      if (!formattedPhone.startsWith('+')) {
        formattedPhone = '+91$formattedPhone';
      }

      final String bioText = _bioController.text.trim().isEmpty
          ? "Dedicated to making an impact."
          : _bioController.text.trim();

      final String avatarUrl = 'https://api.dicebear.com/7.x/bottts/png?seed=${_nameController.text.trim()}';

      final AuthResponse response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _nameController.text.trim(),
          'role': _selectedRole,
          'phone_number': formattedPhone,
          'bio': bioText,
          'address_text': _addressController.text.trim(),
          'avatar_url': avatarUrl,
        },
      );

      if (mounted && response.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Registration successful! Welcome to Anndaan.", style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: AppTheme.primaryEmerald
          ),
        );

        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
              (route) => false,
        );
      }

    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: AppTheme.destructiveRed),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration Error: ${e.toString()}"), backgroundColor: AppTheme.destructiveRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.bgGradientStart,
              AppTheme.primaryLight, // Blending your brand tint into the background
              AppTheme.bgGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.volunteer_activism_rounded, size: 48, color: AppTheme.primaryEmerald),
                const SizedBox(height: 16),
                const Text(
                  "Join Anndaan",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.textDark, letterSpacing: -1.0),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Create your profile to start making an impact.",
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Glassmorphic Form Card
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryEmerald.withValues(alpha: 0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.85),
                              Colors.white.withValues(alpha: 0.5),
                            ],
                          ),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Account Type"),
                              DropdownButtonFormField<String>(
                                value: _selectedRole,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryEmerald),
                                decoration: _inputDecoration("Select your role", Icons.groups_rounded),
                                style: const TextStyle(color: AppTheme.textDark, fontSize: 14, fontWeight: FontWeight.bold),
                                items: const [
                                  DropdownMenuItem(value: 'receiver', child: Text("Receiver (NGO / Shelter)")),
                                  DropdownMenuItem(value: 'donor', child: Text("Donor (Restaurant / Caterer)")),
                                  DropdownMenuItem(value: 'volunteer', child: Text("Volunteer (Driver)")),
                                ],
                                onChanged: (value) {
                                  if (value != null) setState(() => _selectedRole = value);
                                },
                              ),
                              const SizedBox(height: 20),

                              _buildLabel("Full Name / Organization"),
                              TextFormField(
                                controller: _nameController,
                                decoration: _inputDecoration("Enter your full name", Icons.badge_rounded),
                                validator: (val) => val == null || val.isEmpty ? "Required" : null,
                              ),
                              const SizedBox(height: 20),

                              _buildLabel("Email Address"),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _inputDecoration("name@example.com", Icons.alternate_email_rounded),
                                validator: (val) => val == null || !val.contains('@') ? "Valid email required" : null,
                              ),
                              const SizedBox(height: 20),

                              _buildLabel("Phone Number"),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: _inputDecoration("Enter 10-digit number", Icons.phone_iphone_rounded).copyWith(
                                    prefixText: "+91  ",
                                    prefixStyle: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14)
                                ),
                                validator: (val) => val == null || val.length < 10 ? "Valid phone required" : null,
                              ),
                              const SizedBox(height: 20),

                              _buildLabel("Secure Password"),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: _inputDecoration("Minimum 6 characters", Icons.lock_rounded),
                                validator: (val) => val == null || val.length < 6 ? "Too short" : null,
                              ),
                              const SizedBox(height: 20),

                              _buildLabel("Address Location"),
                              TextFormField(
                                controller: _addressController,
                                decoration: _inputDecoration("City, State, Zip", Icons.map_rounded),
                                validator: (val) => val == null || val.isEmpty ? "Required" : null,
                              ),
                              const SizedBox(height: 36),

                              // Premium Tactile Action Button
                              Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryEmerald.withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleSignUp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryEmerald,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                                    )
                                        : const Text("Create Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.textDark, letterSpacing: 0.5)),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26, fontSize: 14, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: AppTheme.primaryEmerald.withValues(alpha: 0.7), size: 22),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.6), // Translucent inputs to sell the glass effect
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryEmerald, width: 2.0)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.destructiveRed, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.destructiveRed, width: 2.0)),
    );
  }
}
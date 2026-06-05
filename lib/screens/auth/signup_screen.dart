import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  static const _accent = Color(0xFF00D4AA);
  static const _errorColor = Color(0xFFFF6B6B);
  final _authService = AuthService();

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Please fix the errors above'),
            ],
          ),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      await _authService.signUp(
        fullName: fullName,
        username: username,
        email: email,
        phone: phone,
        password: password,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/email-verification',
          arguments: {'email': email},
        );
      }
    } catch (e) {
      if (mounted) _showError(_parseError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('username already taken')) {
      return 'This username is not available';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already registered')) {
      return 'An account with this email already exists';
    }
    if (msg.contains('password should be at least') ||
        msg.contains('weak password')) {
      return 'Password must be at least 8 characters';
    }
    if (msg.contains('invalid email') || msg.contains('unable to validate')) {
      return 'Please enter a valid email address';
    }
    if (msg.contains('network') ||
        msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup')) {
      return 'Please check your internet connection';
    }
    return error.toString();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon),
      suffixIcon: suffixIcon,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      errorStyle: const TextStyle(
        color: _errorColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _errorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _errorColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: _accent, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Splivy',
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                Text(
                  'Create Account',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Join Splivy today',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),

                const SizedBox(height: 40),

                TextFormField(
                  controller: _fullNameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: onSurface),
                  decoration: _fieldDecoration(
                    hint: 'Full Name',
                    prefixIcon: Icons.person_outline,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    if (value.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                      return 'Name can only contain letters and spaces';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _usernameController,
                  keyboardType: TextInputType.text,
                  style: TextStyle(color: onSurface),
                  decoration: _fieldDecoration(
                    hint: 'Username',
                    prefixIcon: Icons.alternate_email,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    if (value.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    if (value.trim().length > 20) {
                      return 'Username cannot exceed 20 characters';
                    }
                    if (value.contains(' ')) {
                      return 'Username cannot contain spaces';
                    }
                    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]+$')
                        .hasMatch(value.trim())) {
                      return 'Start with a letter; only letters, numbers, underscore';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: onSurface),
                  decoration: _fieldDecoration(
                    hint: 'Email',
                    prefixIcon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$')
                        .hasMatch(value.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: onSurface),
                  decoration: _fieldDecoration(
                    hint: 'Phone number (e.g. 03001234567)',
                    prefixIcon: Icons.phone_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    if (!RegExp(r'^03[0-9]{9}$').hasMatch(value.trim())) {
                      return 'Enter valid Pakistani number (03XXXXXXXXX)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: onSurface),
                  decoration: _fieldDecoration(
                    hint: 'Password',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
                      return 'Must contain at least one uppercase letter';
                    }
                    if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
                      return 'Must contain at least one lowercase letter';
                    }
                    if (!RegExp(r'(?=.*[0-9])').hasMatch(value)) {
                      return 'Must contain at least one number';
                    }
                    if (!RegExp(r'(?=.*[!@#$%^&*])').hasMatch(value)) {
                      return r'Must contain a special character (!@#$%^&*)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: TextStyle(color: onSurface),
                  decoration: _fieldDecoration(
                    hint: 'Confirm Password',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                Center(
                  child: GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () =>
                            Navigator.of(context).pushReplacementNamed('/login'),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                        children: [
                          TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Login',
                            style: TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

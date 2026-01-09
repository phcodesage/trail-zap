import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:trailzap/providers/auth_provider.dart';
import 'package:trailzap/utils/constants.dart';
import 'package:trailzap/widgets/gradient_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = 'Please agree to the Terms of Service';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    final success = await ref.read(authNotifierProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          username: _usernameController.text.trim(),
        );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Show success and navigate back to login
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.primaryGreen),
                const Gap(12),
                const Text('Account created! Please check your email.'),
              ],
            ),
            backgroundColor: AppColors.darkCard,
          ),
        );
        Navigator.of(context).pop();
      } else {
        final authState = ref.read(authNotifierProvider);
        setState(() {
          _errorMessage = authState.error?.toString() ?? 'Sign up failed';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(20),

                // Header
                _buildHeader(),

                const Gap(40),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const Gap(12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().shake(),

                if (_errorMessage != null) const Gap(24),

                // Username Field
                _buildUsernameField(),

                const Gap(16),

                // Email Field
                _buildEmailField(),

                const Gap(16),

                // Password Field
                _buildPasswordField(),

                const Gap(16),

                // Confirm Password Field
                _buildConfirmPasswordField(),

                const Gap(20),

                // Terms Checkbox
                _buildTermsCheckbox(),

                const Gap(32),

                // Sign Up Button
                GradientButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  isLoading: _isLoading,
                  gradient: AppColors.accentGradient,
                  child: const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const Gap(24),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                      },
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.accentGradient.createShader(bounds),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const Gap(40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),

        const Gap(8),

        Text(
          'Join TrailZap and start tracking your adventures',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.none,
      autocorrect: false,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Username',
        hintText: 'Choose a username',
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          child: const Icon(Icons.person_outline),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a username';
        }
        if (value.length < 3) {
          return 'Username must be at least 3 characters';
        }
        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
          return 'Only letters, numbers, and underscores allowed';
        }
        return null;
      },
    ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1);
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'Enter your email',
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          child: const Icon(Icons.email_outlined),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1);
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Create a strong password',
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          child: const Icon(Icons.lock_outline),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a password';
        }
        if (value.length < 8) {
          return 'Password must be at least 8 characters';
        }
        if (!RegExp(r'[A-Z]').hasMatch(value)) {
          return 'Password must contain an uppercase letter';
        }
        if (!RegExp(r'[0-9]').hasMatch(value)) {
          return 'Password must contain a number';
        }
        return null;
      },
    ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1);
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleSignup(),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        hintText: 'Re-enter your password',
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          child: const Icon(Icons.lock_outline),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
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
    ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1);
  }

  Widget _buildTermsCheckbox() {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _agreedToTerms = !_agreedToTerms;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _agreedToTerms
                      ? AppColors.primaryGreen
                      : AppColors.darkDivider,
                  width: 2,
                ),
                gradient: _agreedToTerms ? AppColors.primaryGradient : null,
              ),
              child: _agreedToTerms
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const Gap(12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 700.ms);
  }
}

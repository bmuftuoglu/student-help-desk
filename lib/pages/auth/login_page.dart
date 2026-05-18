import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onRegisterTap;
  final VoidCallback onLoginSuccess;
  final VoidCallback onForgotPasswordTap;

  const LoginPage({
    super.key,
    required this.onRegisterTap,
    required this.onLoginSuccess,
    required this.onForgotPasswordTap,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
      );
      return;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir e-posta adresi girin')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) widget.onLoginSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
      if (mounted) widget.onLoginSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google girişi başarısız: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppConstants.kDarkBackground : AppConstants.kBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppConstants.kPrimary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 24),
              Text('Tekrar hoş geldin!',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 6),
              Text(
                'Hesabınıza giriş yapın',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
                ),
              ),
              const SizedBox(height: 40),
              _label('E-posta'),
              const SizedBox(height: 8),
              _field(
                controller: _emailController,
                hint: 'ornek@email.com',
                keyboardType: TextInputType.emailAddress,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _label('Şifre'),
              const SizedBox(height: 8),
              _field(
                controller: _passwordController,
                hint: '••••••••',
                obscureText: _obscurePassword,
                isDark: isDark,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: widget.onForgotPasswordTap,
                  child: const Text(
                    'Şifremi Unuttum?',
                    style: TextStyle(
                      color: AppConstants.kPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _primaryBtn(label: 'Giriş Yap', onTap: _handleLogin),
              const SizedBox(height: 24),
              _orDivider(isDark),
              const SizedBox(height: 24),
              _googleBtn(isDark),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hesabınız yok mu?  ',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onRegisterTap,
                    child: const Text(
                      'Kayıt Ol',
                      style: TextStyle(
                        color: AppConstants.kPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(
        fontSize: 15,
        color: isDark ? AppConstants.kDarkTextPrimary : AppConstants.kTextPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 15,
          color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
        ),
        filled: true,
        fillColor: isDark ? AppConstants.kDarkInputFill : AppConstants.kInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppConstants.kDarkBorder : AppConstants.kBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppConstants.kPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: suffix,
      ),
    );
  }

  Widget _primaryBtn({required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.kPrimary,
          disabledBackgroundColor: AppConstants.kPrimary.withValues(alpha: 0.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }

  Widget _orDivider(bool isDark) {
    final c = isDark ? AppConstants.kDarkBorder : AppConstants.kBorder;
    return Row(
      children: [
        Expanded(child: Divider(color: c)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'veya',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
            ),
          ),
        ),
        Expanded(child: Divider(color: c)),
      ],
    );
  }

  Widget _googleBtn(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
            color: isDark ? AppConstants.kDarkBorder : AppConstants.kBorder,
          ),
          backgroundColor: isDark ? AppConstants.kDarkSurface : AppConstants.kSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(
              'Google ile Giriş Yap',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppConstants.kDarkTextPrimary : AppConstants.kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

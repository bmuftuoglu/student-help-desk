import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  final VoidCallback onBackTap;

  const ForgotPasswordPage({super.key, required this.onBackTap});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleResetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen e-posta adresinizi girin')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.resetPassword(email: email);
      if (mounted) setState(() => _emailSent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGoBack() {
    _emailController.clear();
    setState(() => _emailSent = false);
    widget.onBackTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? AppConstants.kDarkBackground : AppConstants.kBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? AppConstants.kDarkBackground : AppConstants.kBackground,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? AppConstants.kDarkSurface : AppConstants.kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppConstants.kDarkBorder : AppConstants.kBorder,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: isDark ? AppConstants.kDarkTextPrimary : AppConstants.kTextPrimary,
            ),
          ),
          onPressed: _handleGoBack,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _emailSent ? _buildSuccessState(isDark) : _buildFormState(isDark),
      ),
    );
  }

  Widget _buildFormState(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppConstants.kPrimaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.lock_reset_rounded,
              color: AppConstants.kPrimary, size: 28),
        ),
        const SizedBox(height: 24),
        Text('Şifreni Sıfırla',
            style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 10),
        Text(
          'Kayıtlı e-posta adresinizi girin. Size şifre sıfırlama bağlantısı göndereceğiz.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
          ),
        ),
        const SizedBox(height: 32),
        const Text('E-posta',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? AppConstants.kDarkTextPrimary : AppConstants.kTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'ornek@email.com',
            hintStyle: TextStyle(
              fontSize: 15,
              color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
            ),
            prefixIcon: Icon(
              Icons.email_outlined,
              size: 20,
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
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleResetPassword,
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
                : const Text(
                    'Sıfırlama Bağlantısı Gönder',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 48),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 44),
        ),
        const SizedBox(height: 28),
        Text(
          'E-posta Gönderildi!',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Şifre sıfırlama bağlantısı\n${_emailController.text}\nadresine gönderildi.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleGoBack,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.kPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Giriş Sayfasına Dön',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

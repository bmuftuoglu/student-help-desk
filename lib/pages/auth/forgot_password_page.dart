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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleGoBack,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Şifreni Sıfırla',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                _emailSent
                    ? 'Sıfırlama bağlantısı e-posta adresinize gönderildi. Lütfen e-posta kutunuzu kontrol edin.'
                    : 'Kayıtlı e-posta adresinizi girin. Size şifre sıfırlama bağlantısı göndereceğiz.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 32),
              if (!_emailSent) ...[
                Text('E-posta',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'ornek@email.com',
                    hintStyle: TextStyle(
                        color:
                            isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                    filled: true,
                    fillColor: isDarkMode
                        ? const Color.fromARGB(57, 35, 35, 35)
                        : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color:
                          isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      disabledBackgroundColor: Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Sıfırlama Bağlantısı Gönder',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Geri dönmek için yukarıdaki oka tıkla',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ),
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      const Icon(
                        Icons.check_circle,
                        size: 80,
                        color: AppConstants.primaryColor,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'E-posta Gönderildi!',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Şifre sıfırlama bağlantısı ${_emailController.text} adresine gönderildi.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleGoBack,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Giriş Sayfasına Dön',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

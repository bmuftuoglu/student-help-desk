import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final parts = (user?.displayName ?? '').trim().split(' ');
    final firstName = parts.isNotEmpty ? parts[0] : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    _firstNameController = TextEditingController(text: firstName);
    _lastNameController = TextEditingController(text: lastName);
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  Future<void> _handleSave() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
      _showSnackBar('Ad, soyad ve e-posta boş bırakılamaz.');
      return;
    }

    if (newPassword.isNotEmpty) {
      if (newPassword.length < 6) {
        _showSnackBar('Yeni şifre en az 6 karakter olmalıdır.');
        return;
      }
      if (newPassword != confirmPassword) {
        _showSnackBar('Yeni şifreler eşleşmiyor.');
        return;
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    final emailChanged = email != (user?.email ?? '');
    final passwordChanging = newPassword.isNotEmpty;

    if ((emailChanged || passwordChanging) && currentPassword.isEmpty) {
      _showSnackBar('E-posta veya şifre değiştirmek için mevcut şifrenizi girin.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (emailChanged || passwordChanging) {
        await _authService.reauthenticate(password: currentPassword);
      }

      final currentDisplayName = user?.displayName ?? '';
      final newDisplayName = '$firstName $lastName'.trim();
      if (newDisplayName != currentDisplayName) {
        await _authService.updateProfileName(
          firstName: firstName,
          lastName: lastName,
        );
      }

      if (emailChanged) {
        await _authService.updateUserEmail(newEmail: email);
      }

      if (passwordChanging) {
        await _authService.updateUserPassword(newPassword: newPassword);
      }

      if (!mounted) return;

      final msg = emailChanged
          ? 'Profil güncellendi. Yeni e-posta adresinize doğrulama bağlantısı gönderildi.'
          : 'Profil başarıyla güncellendi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showSnackBar('$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppConstants.kDarkBackground : AppConstants.kBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? AppConstants.kDarkBackground : AppConstants.kSurface,
        foregroundColor: isDark ? AppConstants.kDarkTextPrimary : AppConstants.kTextPrimary,
        title: const Text('Profili Düzenle'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppConstants.kDarkBorder : AppConstants.kBorder,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),

              // Avatar
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4361EE), Color(0xFF738BFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(displayName),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  displayName.isNotEmpty ? displayName : 'Kullanıcı',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppConstants.kDarkTextPrimary : AppConstants.kTextPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              _sectionLabel('Kişisel Bilgiler', isDark),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildField('Ad', 'Adınız', _firstNameController, isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField('Soyad', 'Soyadınız', _lastNameController, isDark),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildField('E-posta', 'ornek@email.com', _emailController, isDark,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 28),

              _sectionLabel('Şifre Değiştir', isDark),
              const SizedBox(height: 6),
              Text(
                'Şifre veya e-posta değiştirmek için mevcut şifreniz gereklidir.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
                ),
              ),
              const SizedBox(height: 14),
              _buildPasswordField('Mevcut Şifre', _currentPasswordController,
                  _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent), isDark),
              const SizedBox(height: 14),
              _buildPasswordField('Yeni Şifre', _newPasswordController, _obscureNew,
                  () => setState(() => _obscureNew = !_obscureNew), isDark),
              const SizedBox(height: 14),
              _buildPasswordField('Yeni Şifre Tekrar', _confirmPasswordController,
                  _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm), isDark),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
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
                          'Kaydet',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
      ),
    );
  }

  Widget _buildField(
    String label,
    String hint,
    TextEditingController controller,
    bool isDark, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppConstants.kDarkTextPrimary : AppConstants.kTextPrimary,
          ),
          decoration: _inputDecoration(hint, isDark),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool obscure,
    VoidCallback onToggle,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppConstants.kDarkTextPrimary : AppConstants.kTextPrimary,
          ),
          decoration: _inputDecoration('••••••••', isDark).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: isDark ? AppConstants.kDarkTextSecondary : AppConstants.kTextSecondary,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 14,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

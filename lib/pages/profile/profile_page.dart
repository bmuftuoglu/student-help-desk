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
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

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
      _showSnackBar(
          'E-posta veya şifre değiştirmek için mevcut şifrenizi girin.');
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showSnackBar('$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        title: const Text('Profili Düzenle'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Center(
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor:
                      isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  child: Text(
                    _getInitials(displayName),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _sectionLabel('Kişisel Bilgiler', isDarkMode),
              const SizedBox(height: 12),
              _buildField('Ad', 'Adınız', _firstNameController, isDarkMode),
              const SizedBox(height: 16),
              _buildField(
                  'Soyad', 'Soyadınız', _lastNameController, isDarkMode),
              const SizedBox(height: 16),
              _buildField(
                'E-posta',
                'ornek@email.com',
                _emailController,
                isDarkMode,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 32),
              _sectionLabel('Şifre Değiştir', isDarkMode),
              const SizedBox(height: 4),
              Text(
                'Şifre veya e-posta değiştirmek için mevcut şifreniz gereklidir.'
                ' Yeni şifre girmek istemiyorsanız boş bırakın.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildPasswordField(
                'Mevcut Şifre',
                _currentPasswordController,
                _obscureCurrent,
                () => setState(() => _obscureCurrent = !_obscureCurrent),
                isDarkMode,
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                'Yeni Şifre',
                _newPasswordController,
                _obscureNew,
                () => setState(() => _obscureNew = !_obscureNew),
                isDarkMode,
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                'Yeni Şifre Tekrar',
                _confirmPasswordController,
                _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm),
                isDarkMode,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
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
                          'Kaydet',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
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

  Widget _sectionLabel(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildField(
    String label,
    String hint,
    TextEditingController controller,
    bool isDarkMode, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          decoration: _inputDecoration(hint, isDarkMode),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool obscure,
    VoidCallback onToggle,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          decoration: _inputDecoration('••••••••', isDarkMode).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDarkMode) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
      filled: true,
      fillColor:
          isDarkMode ? const Color.fromARGB(57, 35, 35, 35) : Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

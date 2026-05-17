import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const AuthPage({super.key, required this.onLoginSuccess});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLoginPage = true;
  bool _isForgotPasswordPage = false;

  @override
  Widget build(BuildContext context) {
    if (_isForgotPasswordPage) {
      return ForgotPasswordPage(
        onBackTap: () => setState(() => _isForgotPasswordPage = false),
      );
    }

    return _isLoginPage
        ? LoginPage(
            onRegisterTap: () => setState(() => _isLoginPage = false),
            onLoginSuccess: widget.onLoginSuccess,
            onForgotPasswordTap: () =>
                setState(() => _isForgotPasswordPage = true),
          )
        : RegisterPage(
            onLoginTap: () => setState(() => _isLoginPage = true),
            onRegisterSuccess: widget.onLoginSuccess,
          );
  }
}

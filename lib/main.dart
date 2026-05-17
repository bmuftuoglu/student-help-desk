import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'pages/chat/chat_page.dart';
import 'pages/auth/auth_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved == null) return;
    setState(() {
      _themeMode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme() async {
    final next = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() => _themeMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', next == ThemeMode.dark ? 'dark' : 'light');
  }

  void _handleLogout() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Öğrenci Yardım Masası',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return ChatPage(
              onThemeToggle: _toggleTheme,
              onLogout: _handleLogout,
            );
          }
          return AuthPage(onLoginSuccess: () => setState(() {}));
        },
      ),
    );
  }
}

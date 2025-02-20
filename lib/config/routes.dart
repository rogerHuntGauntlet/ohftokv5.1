import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/home/home_page.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/ohftok/ohftok_screen.dart';

class Routes {
  static const String initial = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String followers = '/followers';
  static const String following = '/following';
  static const String notifications = '/notifications';
  static const String analytics = '/analytics';
  static const String ohftok = '/ohftok';

  static final Map<String, Widget Function(BuildContext)> routes = {
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    onboarding: (context) => const OnboardingScreen(),
    home: (context) => const HomePage(),
    profile: (context) => const ProfileScreen(),
    ohftok: (context) => const OhftokScreen(),
    // TODO: Add routes for new features as they are implemented
  };
} 
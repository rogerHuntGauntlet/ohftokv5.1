import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/social/auth_service.dart';
import '../home/home_page.dart';
import '../onboarding/onboarding_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: Provider.of<AuthService>(context).authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasData) {
          return FutureBuilder<bool>(
            future: Provider.of<AuthService>(context, listen: false)
                .hasCompletedOnboarding(snapshot.data!.uid),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (onboardingSnapshot.data == true) {
                return const HomePage();
              } else {
                return const OnboardingScreen();
              }
            },
          );
        }
        
        return const LoginScreen();
      },
    );
  }
} 
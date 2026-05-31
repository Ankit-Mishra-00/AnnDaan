import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/home_role_router.dart';
import '../onboarding/landing_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 1. ⏳ WAITING STATE: Wait until the local cache session stream connects
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
          );
        }

        // 2. 🛡️ ERROR STATE: Handle unexpected stream breakdowns safely
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sync_problem, color: Colors.orange, size: 50),
                    const SizedBox(height: 16),
                    const Text(
                      "Authentication sync delay.\nPlease restart the app.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 3. 🔑 ACTIVE SESSION CHECK
        if (snapshot.hasData) {
          final session = snapshot.data!.session;

          // If a user is securely logged in, pass them to the RBAC role switcher
          if (session != null) {
            return const HomeRoleRouter();
          }
        }

        // 4. 🚪 FALLBACK: If logged out or no session exists, route cleanly to Landing Page
        return const LandingPage();
      },
    );
  }
}
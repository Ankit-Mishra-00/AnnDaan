import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../feed/home_page.dart'; // Standard public/NGO food feed screen
import '../screens/donor_dashboard_screen.dart';
import '../screens/main_navigation_screen.dart';
// 👇 IMPORT YOUR NEW ADMIN PANEL AND SECURITY GUARD COMPONENT
import '../admin/admin_dashboard_screen.dart';
import '../admin/verification_guard_screen.dart';

class HomeRoleRouter extends StatelessWidget {
  const HomeRoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    // Guest Flow: If not logged in at all, let them browse the public home page feed
    if (user == null) {
      return const HomePage();
    }

    // Authenticated Flow: Fetch their security role dynamically
    return FutureBuilder<Map<String, dynamic>>(
      future: Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
        }

        // Fallback: If there's an error or no profile row exists yet
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const MainNavigationScreen();
        }

        final String userRole = snapshot.data!['role'] ?? 'receiver';

        // 🎛️ POLYNORPHIC SECURITY ROLE ROUTER ENGINE
        if (userRole == 'admin') {
          // ✨ NEW: Route administrators straight to the global control command deck
          return const AdminDashboardScreen();
        }

        if (userRole == 'donor') {
          // Donors bypass the verification block layout safely to post food supply batches
          return const DonorDashboardScreen();
        }

        // ✨ NEW: Protect incoming Volunteers and NGO Receivers with the security check layout wrapper
        return const VerificationGuardScreen(
          child: MainNavigationScreen(),
        );
      },
    );
  }
}
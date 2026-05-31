import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationGuardScreen extends StatelessWidget {
  final Widget child;

  const VerificationGuardScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return const Center(child: Text("Session Expired"));

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('profiles').stream(primaryKey: ['id']).eq('id', user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
        }

        final profileList = snapshot.data ?? [];
        if (profileList.isEmpty) return child;

        final profile = profileList.first;
        final bool isVerified = profile['is_verified'] ?? false;
        final String role = profile['role'] ?? 'volunteer';

        // 🛡️ PASS VERIFICATION CHECK: If verified or if user is a Donor/Admin, bypass the guard
        if (isVerified || role == 'donor' || role == 'admin') {
          return child;
        }

        // 🛑 BLOCKED WORKSPACE: Display a secure placeholder block
        return Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.gavel_rounded, size: 64, color: Colors.redAccent),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Verification Review Pending",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  "Your profile registration request as a ${role.toUpperCase()} is currently in our verification queue. An administrator will activate your logistics clearance privileges shortly.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Log Out Safely", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
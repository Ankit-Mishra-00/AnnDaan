import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _darkMode = false;
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _buildSectionHeader("Account & Preferences"),
          _buildSettingsTile(
            icon: Icons.person_outline,
            title: "Edit Profile Details",
            subtitle: "Update your name, contact phone, or address",
            onTap: () {
              // Custom Edit Profile logic can link here later!
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Profile editing panel coming soon!")),
              );
            },
          ),

          // Interactive Toggle Switch for Push Notifications
          SwitchListTile.adaptive(
            secondary: Icon(Icons.notifications_none, color: Colors.green.shade700),
            title: const Text("Push Notifications", style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text("Alert me when nearby meals need rescue or drivers update statuses"),
            value: _pushNotifications,
            activeColor: Colors.green,
            onChanged: (bool value) {
              setState(() => _pushNotifications = value);
            },
          ),

          // Interactive Toggle Switch for App Dark Mode Theme
          SwitchListTile.adaptive(
            secondary: Icon(Icons.dark_mode_outlined, color: Colors.green.shade700),
            title: const Text("Dark Theme Mode", style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text("Switch interface to custom low-light colors"),
            value: _darkMode,
            activeColor: Colors.green,
            onChanged: (bool value) {
              setState(() => _darkMode = value);
            },
          ),

          const Divider(height: 32),
          _buildSectionHeader("Support & Legal"),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: "Help Center & FAQ",
            subtitle: "Troubleshoot collection loops and verification steps",
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.policy_outlined,
            title: "Privacy Policy & Terms",
            subtitle: "View data usage rules and marketplace guidelines",
            onTap: () {},
          ),

          const Divider(height: 32),
          // Destructive Account Action Block
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: Colors.red,
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text("Delete Account Permanently", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _confirmAccountDeletion(context),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.green.shade700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _confirmAccountDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Account?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("This action is completely irreversible. All your transaction history, earned green points, and registered listing details will be wiped out completely."),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Yes, Delete My Data", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              try {
                final userId = _supabase.auth.currentUser?.id;
                if (userId != null) {
                  // Wipe row profile information, then delete global session engine instance
                  await _supabase.from('profiles').delete().eq('id', userId);
                  await _supabase.auth.signOut();
                }
                if (!context.mounted) return;
                // Pop both dialog and settings screen to boot back out to landing registration view
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Action failed: ${e.toString()}"), backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
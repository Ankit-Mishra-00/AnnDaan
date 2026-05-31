import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmergencyHubBottomSheet extends StatefulWidget {
  final String? activeOrderId;
  final String userRole; // Accepts: 'volunteer', 'donor', 'receiver'

  const EmergencyHubBottomSheet({
    super.key,
    this.activeOrderId,
    required this.userRole,
  });

  // Static helper to display this sheet cleanly from any button tap in your app
  static void show(BuildContext context, {String? activeOrderId, required String userRole}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1515), // Deep emergency dark red-tint base
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => EmergencyHubBottomSheet(
        activeOrderId: activeOrderId,
        userRole: userRole,
      ),
    );
  }

  @override
  State<EmergencyHubBottomSheet> createState() => _EmergencyHubBottomSheetState();
}

class _EmergencyHubBottomSheetState extends State<EmergencyHubBottomSheet> {
  bool _isLogging = false;

  Future<void> _handleEmergencyAction(String alertType, String phoneNumber) async {
    setState(() => _isLogging = true);

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    try {
      // 1. Log the alert payload directly to the Supabase database table
      await supabase.from('emergency_alerts').insert({
        'user_id': user?.id,
        'order_id': widget.activeOrderId,
        'user_role': widget.userRole,
        'alert_type': alertType,
      });
      debugPrint("🚨 Telemetry successfully dispatched to control room: $alertType");
    } catch (e) {
      // Fail silently for the user so it doesn't block their phone call in an emergency
      debugPrint("⚠️ Telemetry logging failed: $e");
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }

    // 2. Open up the native device dialer framework
    final Uri telUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      // Use launchUrl directly with an explicit external Application mode
      await launchUrl(
        telUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to open dialer automatically: $phoneNumber")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Handles padding correctly when system or notch layouts shift
      padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 16.0,
          bottom: MediaQuery.of(context).padding.bottom + 24.0
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Elegant top drag handle indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Emergency & Support', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 2),
                    Text('Choose an option below to secure assistance.', style: TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // 🚨 BUTTON 1: LOCAL AUTHORITIES / POLICE
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C), // Strong Alert Red
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _isLogging ? null : () => _handleEmergencyAction('police_clicked', '100'), // Adjust to 911 / 112 as per your region
            icon: const Icon(Icons.local_police_rounded, size: 22),
            label: const Text('Call Local Police (100)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 14),

          // 📞 BUTTON 2: ANNDAAN CORE EMERGENCY LINE
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100), // Alert Amber / Orange
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _isLogging ? null : () => _handleEmergencyAction('support_clicked', '+919876543210'), // Replace with your active helpline number
            icon: const Icon(Icons.support_agent_rounded, size: 22),
            label: const Text('Call Anndaan Safety Desk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Divider(color: Colors.white12, height: 1),
          ),

          // 💡 SAFETY PRECAUTIONS PANEL
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: Colors.green.shade400, size: 20),
              const SizedBox(width: 8),
              Text('Safety Guidelines for ${widget.userRole.toUpperCase()}s', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade400)),
            ],
          ),
          const SizedBox(height: 14),

          // Dynamic safety tips targeting specific roles
          ..._getSafetyTipsForRole(widget.userRole),
        ],
      ),
    );
  }

  List<Widget> _getSafetyTipsForRole(String role) {
    if (role == 'volunteer') {
      return [
        _buildTipItem("Park Safely", "Pull over to a legal, well-lit parking spot before opening your app or checking navigation parameters."),
        _buildTipItem("Doorstep Handovers", "Avoid walking inside unverified residential or storage zones alone. Request cargo drops at the main entrance threshold."),
        _buildTipItem("Hygiene Guard", "If food quality smells foul or violates basic health protocols, decline the transit run and flag it down right away."),
      ];
    } else if (role == 'donor') {
      return [
        _buildTipItem("Public Handover", "Keep collection materials grouped near your facility dock or open reception deck for straightforward driver matching."),
        _buildTipItem("Identity Check", "Verify the driver's name on your screen matches the arriving volunteer before handoff processing."),
      ];
    } else {
      return [
        _buildTipItem("Check Food Instantly", "Inspect container packaging seals and thermal state as soon as logistics delivery completes."),
      ];
    }
  }

  Widget _buildTipItem(String title, String explanation) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(),
            child: Icon(Icons.circle, color: Colors.white30, size: 6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4, fontFamily: 'sans-serif'),
                children: [
                  TextSpan(text: "$title: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  TextSpan(text: explanation),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
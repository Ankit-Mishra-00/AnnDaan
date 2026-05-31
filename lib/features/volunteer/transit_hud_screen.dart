import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'dart:io';
import '../../widgets/review_bottom_sheet.dart';
import '../../widgets/emergency_hub_bottom_sheet.dart';

class TransitHudScreen extends StatefulWidget {
  final Map<String, dynamic> deliveryJob;

  const TransitHudScreen({super.key, required this.deliveryJob});

  @override
  State<TransitHudScreen> createState() => _TransitHudScreenState();
}

class _TransitHudScreenState extends State<TransitHudScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    // Initialize state with whatever value was passed from the dashboard snapshot stream
    _currentStatus = widget.deliveryJob['status']?.toString() ?? 'assigned_to_volunteer';
  }

  // Maps database string values to human-readable milestone indicator strings cleanly
  String _getStatusHeadingText() {
    switch (_currentStatus) {
      case 'assigned_to_volunteer':
      case 'claimed':
        return 'ROUTE ACCEPTED';
      case 'en_route_to_pickup':
        return 'EN ROUTE TO PICKUP';
      case 'arrived_at_pickup':
        return 'ARRIVED AT PICKUP SITE';
      case 'in_transit':
        return 'EN ROUTE TO NGO DESTINATION';
      default:
        return 'PROCESSING LOGISTICS';
    }
  }

  // Calculates which index step needs active highlighting inside our stepper node
  int _getStepIndex() {
    if (_currentStatus == 'en_route_to_pickup') return 1;
    if (_currentStatus == 'arrived_at_pickup') return 2;
    if (_currentStatus == 'in_transit') return 3;
    return 0; // Baseline fallback matching initial assignment state
  }

  Future<void> _advanceMilestone() async {
    setState(() => _isLoading = true);

    String nextStatus;
    bool isFullyCompleted = false;

    // Determine target milestone state step based on our state progression rules
    if (_currentStatus == 'assigned_to_volunteer' || _currentStatus == 'claimed') {
      nextStatus = 'en_route_to_pickup';
    } else if (_currentStatus == 'en_route_to_pickup') {
      nextStatus = 'arrived_at_pickup';
    } else if (_currentStatus == 'arrived_at_pickup') {
      nextStatus = 'in_transit';
    } else {
      nextStatus = 'completed';
      isFullyCompleted = true;
    }

    try {
      await _supabase
          .from('food_listings')
          .update({'status': nextStatus})
          .eq('id', widget.deliveryJob['id']);

      setState(() {
        _currentStatus = nextStatus;
        _isLoading = false;
      });

      if (isFullyCompleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rescue successfully completed! Metrics updated.'), backgroundColor: Color(0xFF2E7D32)),
        );

        final String orderId = widget.deliveryJob['id']?.toString() ?? '0';
        final String ngoId = widget.deliveryJob['ngo_id']?.toString() ?? '';
        final String ngoName = widget.deliveryJob['ngo_name']?.toString() ?? 'Destination Facility';

        Navigator.of(context).pop(true);

        ReviewBottomSheet.show(
          context,
          orderId: orderId,
          revieweeId: ngoId,
          revieweeRole: PlatformRole.receiverNgo,
          reviewerRole: PlatformRole.volunteer,
          targetName: ngoName,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update milestone checkpoint: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _launchNavigation(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    Uri mapUri = Platform.isIOS
        ? Uri.parse("https://maps.apple.com/?q=$encodedAddress")
        : Uri.parse("geo:0,0?q=$encodedAddress");

    try {
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      } else if (Platform.isAndroid) {
        final webFallback = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedAddress");
        if (await canLaunchUrl(webFallback)) {
          await launchUrl(webFallback, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening navigation: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _abortRoute(String reason) async {
    setState(() => _isLoading = true);
    try {
      String targetStatus = (reason == 'spoiled') ? 'cancelled' : 'available';
      await _supabase.from('food_listings').update({'status': targetStatus, 'volunteer_id': null}).eq('id', widget.deliveryJob['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Route aborted. Status marked as $targetStatus.')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear route: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Abort Active Delivery?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Select primary reason for auditing:', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () { Navigator.pop(context); _abortRoute('vehicle_breakdown'); }, child: const Text('Transit Issue', style: TextStyle(color: Colors.orangeAccent))),
          TextButton(onPressed: () { Navigator.pop(context); _abortRoute('spoiled'); }, child: const Text('Food Spoiled', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String foodTitle = widget.deliveryJob['title'] ?? 'Food Rescue Batch';
    final String pickupAddress = widget.deliveryJob['pickup_address'] ?? 'Donor Kitchen Location';
    final String dropoffAddress = widget.deliveryJob['dropoff_address'] ?? 'NGO Destination Facility';
    final String foodQuantity = widget.deliveryJob['quantity'] ?? 'Not specified';

    // Button text transformations based on dynamic status pointers
    String buttonLabel = "Start Route (Go to Pickup)";
    if (_currentStatus == 'en_route_to_pickup') buttonLabel = "I Have Arrived at Donor Location";
    if (_currentStatus == 'arrived_at_pickup') buttonLabel = "Food Collected (Start Transit)";
    if (_currentStatus == 'in_transit') buttonLabel = "Confirm Safe Drop-off at NGO";

    return Scaffold(
      backgroundColor: const Color(0xFF0F1210),
      appBar: AppBar(
        title: const Text('Live Transit HUD', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF141916),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            onPressed: _isLoading ? null : _showCancelDialog,
          )
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
        onPressed: () => EmergencyHubBottomSheet.show(context, activeOrderId: widget.deliveryJob['id']?.toString(), userRole: 'volunteer'),
        backgroundColor: const Color(0xFFB71C1C),
        icon: const Icon(Icons.shield_outlined, color: Colors.white),
        label: const Text('EMERGENCY SOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📊 PIPELINE STATUS INDICATOR CARD
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.alt_route_rounded, color: Color(0xFF81C784), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _getStatusHeadingText(),
                        style: const TextStyle(color: Color(0xFF81C784), fontWeight: FontWeight.bold, letterSpacing: 0.8, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Visual Segment Stepper Bar Block
                  Row(
                    children: List.generate(4, (index) {
                      bool isPassed = index <= _getStepIndex();
                      return Expanded(
                        child: Container(
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isPassed ? const Color(0xFF4CAF50) : Colors.white12,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CORE CARGO DETAILS PANEL
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(foodTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('Payload Metrics: $foodQuantity', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                      const Divider(height: 32, color: Colors.white12),

                      _buildTargetRoutingTile(
                        icon: Icons.location_on,
                        iconColor: _getStepIndex() < 2 ? Colors.orangeAccent : Colors.white38,
                        label: 'PICKUP FROM (DONOR)',
                        address: pickupAddress,
                        onNavigate: () => _launchNavigation(pickupAddress),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 18.0),
                        child: Text('┊', style: TextStyle(color: _getStepIndex() >= 3 ? const Color(0xFF4CAF50) : Colors.white24, fontSize: 20)),
                      ),
                      _buildTargetRoutingTile(
                        icon: Icons.flag,
                        iconColor: _getStepIndex() >= 3 ? const Color(0xFF4CAF50) : Colors.white38,
                        label: 'DROP-OFF SITE (NGO)',
                        address: dropoffAddress,
                        onNavigate: () => _launchNavigation(dropoffAddress),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),

            // Dynamic Checkpoint Action Trigger
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStatus == 'in_transit' ? const Color(0xFF2E7D32) : const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              onPressed: _advanceMilestone,
              child: Text(
                buttonLabel,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 70),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetRoutingTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required VoidCallback onNavigate,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: iconColor, letterSpacing: 1.0)),
              const SizedBox(height: 4),
              Text(address, style: TextStyle(fontSize: 15, color: iconColor == Colors.white38 ? Colors.white38 : Colors.white, height: 1.3)),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.navigation_rounded, color: iconColor == Colors.white38 ? Colors.white24 : Colors.white70),
          onPressed: iconColor == Colors.white38 ? null : onNavigate,
        ),
      ],
    );
  }
}
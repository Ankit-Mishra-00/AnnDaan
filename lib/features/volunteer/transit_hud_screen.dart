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
  bool _isFetchingContacts = true;
  late String _currentStatus;

  // Local state tracking for profile values pulled live from the schema layout
  String? _donorFetchedPhone;
  String? _donorFetchedName;
  String? _receiverFetchedPhone;
  String? _receiverFetchedName;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.deliveryJob['status']?.toString() ?? 'assigned_to_volunteer';
    _fetchContactDetails();
  }

  // 🌟 Direct database profile retrieval logic mapping directly to your schema
  Future<void> _fetchContactDetails() async {
    final donorId = widget.deliveryJob['donor_id']?.toString();
    final receiverId = widget.deliveryJob['receiver_id']?.toString();

    try {
      // 1. Fetching Donor Profile Properties Data
      if (donorId != null && donorId.isNotEmpty) {
        final donorProfile = await _supabase
            .from('profiles')
            .select('phone_number, full_name')
            .eq('id', donorId)
            .maybeSingle();
        if (donorProfile != null) {
          _donorFetchedPhone = donorProfile['phone_number']?.toString();
          _donorFetchedName = donorProfile['full_name']?.toString();
        }
      }

      // 2. Fetching NGO Receiver Profile Properties Data
      if (receiverId != null && receiverId.isNotEmpty) {
        final receiverProfile = await _supabase
            .from('profiles')
            .select('phone_number, full_name')
            .eq('id', receiverId)
            .maybeSingle();
        if (receiverProfile != null) {
          _receiverFetchedPhone = receiverProfile['phone_number']?.toString();
          _receiverFetchedName = receiverProfile['full_name']?.toString();
        }
      }
    } catch (e) {
      debugPrint("Error loading profile contacts natively: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingContacts = false;
        });
      }
    }
  }

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

  int _getStepIndex() {
    switch (_currentStatus) {
      case 'assigned_to_volunteer':
      case 'claimed':
        return 0;
      case 'en_route_to_pickup':
        return 1;
      case 'arrived_at_pickup':
        return 2;
      case 'in_transit':
        return 3;
      default:
        return 0;
    }
  }

  Future<void> _advanceMilestone() async {
    setState(() => _isLoading = true);

    String nextStatus;
    bool isFullyCompleted = false;

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
        final String ngoId = widget.deliveryJob['receiver_id']?.toString() ?? '';
        final String finalNgoName = _receiverFetchedName ?? widget.deliveryJob['caterer_name'] ?? 'Facility Destination';

        Navigator.of(context).pop(true);

        ReviewBottomSheet.show(
          context,
          orderId: orderId,
          revieweeId: ngoId,
          revieweeRole: PlatformRole.receiverNgo,
          reviewerRole: PlatformRole.volunteer,
          targetName: finalNgoName,
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

  Future<void> _callContactNumber(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact phone details missing for this user profile.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    final Uri phoneLaunchUri = Uri(scheme: 'tel', path: phoneNumber.trim());
    try {
      if (await canLaunchUrl(phoneLaunchUri)) {
        await launchUrl(phoneLaunchUri);
      } else {
        throw 'Could not launch native phone call handling intent';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone dialer: $e'), backgroundColor: Colors.redAccent),
        );
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

    // Dynamic loading configurations fallback strategies
    final String finalDonorName = _donorFetchedName ?? widget.deliveryJob['caterer_name'] ?? 'Anonymous Food Donor';
    final String finalNgoName = _receiverFetchedName ?? 'Destination NGO Facility';

    final int servings = widget.deliveryJob['servings_count'] ?? 0;
    final String weightString = widget.deliveryJob['food_weight_kg'] != null ? "${widget.deliveryJob['food_weight_kg']} kg" : "Unspecified Weight";
    final String foodQuantity = "$servings Servings ($weightString)";

    final String dropoffAddress = widget.deliveryJob['delivery_address']?.toString().isNotEmpty == true
        ? widget.deliveryJob['delivery_address']
        : 'Default Facility Address Location';

    final int currentStep = _getStepIndex();

    String buttonLabel = "Start Route (Go to Pickup)";
    if (currentStep == 1) buttonLabel = "I Have Arrived at Donor Location";
    if (currentStep == 2) buttonLabel = "Food Collected (Start Transit)";
    if (currentStep == 3) buttonLabel = "Confirm Safe Drop-off at NGO";

    bool isPickupActive = currentStep >= 0 && currentStep <= 2;
    bool isDropoffActive = currentStep == 3;

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
            // PIPELINE STATUS INDICATOR CARD
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withAlpha(38),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4CAF50).withAlpha(64)),
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
                  Row(
                    children: List.generate(4, (index) {
                      bool isPassed = index <= currentStep;
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
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withAlpha(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(foodTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('Payload Metrics: $foodQuantity', style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 14)),
                      const Divider(height: 32, color: Colors.white12),

                      // STAGE 1: DONOR LOCATION + COMPLIANT CONTACT INTERFACE
                      _buildTargetRoutingTile(
                        icon: Icons.location_on,
                        iconColor: isPickupActive ? Colors.orangeAccent : Colors.white38,
                        label: 'PICKUP FROM (DONOR)',
                        address: pickupAddress,
                        contactName: finalDonorName,
                        contactPhone: _donorFetchedPhone,
                        isNavigationEnabled: isPickupActive,
                        isFetchingPhone: _isFetchingContacts,
                        onNavigate: () => _launchNavigation(pickupAddress),
                        onCall: () => _callContactNumber(_donorFetchedPhone),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(left: 18.0, top: 4, bottom: 4),
                        child: Text('┊', style: TextStyle(color: currentStep >= 3 ? const Color(0xFF4CAF50) : Colors.white24, fontSize: 20)),
                      ),

                      // STAGE 2: DROPOFF LOCATION + COMPLIANT CONTACT INTERFACE
                      _buildTargetRoutingTile(
                        icon: Icons.flag,
                        iconColor: isDropoffActive ? const Color(0xFF4CAF50) : Colors.white38,
                        label: 'DROP-OFF SITE (NGO)',
                        address: dropoffAddress,
                        contactName: finalNgoName,
                        contactPhone: _receiverFetchedPhone,
                        isNavigationEnabled: isDropoffActive,
                        isFetchingPhone: _isFetchingContacts,
                        onNavigate: () => _launchNavigation(dropoffAddress),
                        onCall: () => _callContactNumber(_receiverFetchedPhone),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: currentStep == 3 ? const Color(0xFF2E7D32) : const Color(0xFF1B5E20),
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
    required String contactName,
    required String? contactPhone,
    required bool isNavigationEnabled,
    required bool isFetchingPhone,
    required VoidCallback onNavigate,
    required VoidCallback onCall,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                  Text(address, style: TextStyle(fontSize: 15, color: isNavigationEnabled ? Colors.white : Colors.white38, height: 1.3)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.navigation_rounded, color: isNavigationEnabled ? Colors.white70 : Colors.white24),
              onPressed: isNavigationEnabled ? onNavigate : null,
            ),
          ],
        ),

        if (isNavigationEnabled) ...[
          Padding(
            padding: const EdgeInsets.only(left: 38.0, top: 8.0, bottom: 4.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor.withAlpha(40), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contactName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        if (isFetchingPhone)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white54),
                          )
                        else
                          Text(
                            (contactPhone != null && contactPhone.trim().isNotEmpty)
                                ? contactPhone
                                : 'No Phone Number Added',
                            style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: iconColor.withAlpha(30),
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: Icon(Icons.phone_in_talk_rounded, color: iconColor, size: 16),
                    onPressed: isFetchingPhone ? null : onCall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
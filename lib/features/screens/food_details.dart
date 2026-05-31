import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/food_actions_service.dart'; // Pointing to your centralized utility file
import '../screens/login_screen.dart'; // Ensure this points to your login page file location

class FoodDetails extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final String expiryText;
  final bool isUrgent;

  const FoodDetails({
    super.key,
    required this.itemData,
    required this.expiryText,
    required this.isUrgent,
  });

  // ✨ NEW: The Master Guard Interceptor Engine
  void _processClaimAction(BuildContext context, String listingId, String title) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    // 🚪 STEP 1: GUEST INTERCEPTION - Catch unauthenticated users immediately
    if (currentUser == null) {
      _showLoginPromptDialog(context);
      return;
    }

    // 🔐 STEP 2: VERIFICATION LEVEL CHECK - Evaluate parameters prior to triggering transactional states
    try {
      // Show background loading indicator while checking database column parameters
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.green)),
      );

      final data = await supabase
          .from('profiles')
          .select('is_verified')
          .eq('id', currentUser.id)
          .single();

      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss loading spinner indicator securely

      final bool isVerified = data['is_verified'] ?? false;

      if (!isVerified) {
        // 🚧 RESTRICTED ACCESS: Halt flow with pending modal warning
        _showPendingVerificationDialog(context);
      } else {
        // 🎉 APPROVED ACCESS: Load operations allocation prompt checklist
        _claimFoodItem(context, listingId, title);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Ensure recovery pop completes safely if failures trigger
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profile verification check failure: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ✨ NEW: Explicit Guest Login Intermediary Panel
  void _showLoginPromptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Authentication Required", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("You need to create an account or login to lock allocations, finalize delivery details, and process cargo claims."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog window overlay safely
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text("Login / Sign Up", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ✨ NEW: Verification Blocking Warning Alert Modal
  void _showPendingVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gpp_maybe_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("Verification Pending"),
          ],
        ),
        content: const Text("Your account details are under review by an administrator. You will gain access to claim batches and assign delivery runs the moment your registration is approved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Understood", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // Prompts the NGO with collection modalities upon claiming
  Future<void> _claimFoodItem(BuildContext parentContext, String listingId, String title) async {
    // ✨ PERSISTENCE FIX: Declared OUTSIDE the StatefulBuilder so it doesn't reset on checkbox clicks
    bool isParcelConfirmed = false;

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: Text("Claim '$title'"),
        content: StatefulBuilder(
          builder: (BuildContext dialogFrameContext, StateSetter setDialogState) { // ✨ CONTEXT FIX: Isolated inner dialog frame
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Please verify your allocation criteria below:",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                // Checkbox controls button state visibility dynamically
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "I confirm that our organization will reliably receive this parcel upon dispatch.",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  value: isParcelConfirmed,
                  activeColor: Colors.green,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (bool? value) {
                    // Updates the isolated state inside the dialog frame overlay smoothly
                    setDialogState(() {
                      isParcelConfirmed = value ?? false;
                    });
                  },
                ),

                if (isParcelConfirmed) ...[
                  const Divider(height: 24),
                  const Text(
                    "Do you need independent volunteer system support to deliver this order, or can your team handle direct transport collection?",
                    style: TextStyle(fontSize: 13, height: 1.3, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Option A: Direct Self-Collection
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          // 1. Close the modal verification overlay panel instantly
                          Navigator.pop(dialogContext);

                          // 2. Fire database mutation using parentContext to protect the asynchronous thread
                          await FoodActionsService.executeClaimTransaction(
                            context: parentContext,
                            listingId: listingId,
                            deliveryType: 'self_pickup',
                            title: title,
                            onSuccess: () {
                              // Pop the details page itself so the user falls back directly to a refreshed feed stream
                              if (Navigator.canPop(parentContext)) {
                                Navigator.pop(parentContext);
                              }
                            },
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.storefront, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "No, Self-Pickup (We will drive)",
                                style: TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Option B: Volunteer Support
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          // 1. Close the modal verification overlay panel instantly
                          Navigator.pop(dialogContext);

                          // 2. Fire database mutation using parentContext to protect the asynchronous thread
                          await FoodActionsService.executeClaimTransaction(
                            context: parentContext,
                            listingId: listingId,
                            deliveryType: 'needs_volunteer',
                            title: title,
                            onSuccess: () {
                              // Pop the details page itself so the user falls back directly to a refreshed feed stream
                              if (Navigator.canPop(parentContext)) {
                                Navigator.pop(parentContext);
                              }
                            },
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.handshake_outlined, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Yes, Need Volunteer Support",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String listingId = itemData['id']?.toString() ?? '';
    final String title = itemData['title'] ?? 'Surplus Food Material';
    final String caterer = itemData['caterer_name'] ?? 'Anonymous Donor';
    final String itemsDesc = itemData['items_description'] ?? 'No description provided.';
    final int servings = itemData['servings_count'] ?? 0;
    final double weight = double.tryParse(itemData['food_weight_kg']?.toString() ?? '0') ?? 0.0;
    final double fee = double.tryParse(itemData['delivery_fee']?.toString() ?? '0') ?? 0.0;
    final String address = itemData['pickup_address'] ?? 'Address detailed on claim receipt';
    final String? imageUrl = itemData['image_url'];
    final bool providesDelivery = itemData['provides_delivery'] ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Food Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image/Cover Widget
            Container(
              height: 220,
              width: double.infinity,
              color: Colors.grey[100],
              child: imageUrl != null
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Center(child: Icon(Icons.restaurant, size: 80, color: Colors.grey.shade400)),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Expiry Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Posted by $caterer", style: const TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isUrgent ? Colors.red.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          expiryText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isUrgent ? Colors.red.shade800 : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Description Segment
                  const Text("Items Included", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(itemsDesc, style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.4)),
                  const Divider(height: 32),

                  // Metrics Row Grid Block
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMetricIcon(Icons.people_alt_outlined, "$servings+", "Servings"),
                      _buildMetricIcon(Icons.scale_outlined, weight > 0 ? "${weight}kg" : "N/A", "Est. Weight"),
                      _buildMetricIcon(
                        providesDelivery ? Icons.local_shipping_outlined : Icons.directions_walk_outlined,
                        providesDelivery ? "Provided" : "Self-Pickup",
                        "Logistics",
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Location Block
                  const Text("Pickup Location Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Bottom Claim Operational Row Panel
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Pricing", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            fee > 0 ? "₹${fee.toStringAsFixed(0)}" : "Free Asset",
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 50,
                        width: MediaQuery.of(context).size.width * 0.55,
                        child: ElevatedButton(
                          // ⚡ ROUTED THROUGH THE SECURITY INTERCEPT ENGINE INSTEAD OF DIRECT CLAIM
                          onPressed: () => _processClaimAction(context, listingId, title),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isUrgent ? Colors.red.shade600 : Colors.green.shade600,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Claim Food Material",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricIcon(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.green.shade600),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
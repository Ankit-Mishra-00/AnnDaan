import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/food_actions_service.dart'; // Pointing to your centralized service file

class ReceiverFeedScreen extends StatefulWidget {
  const ReceiverFeedScreen({super.key});

  @override
  State<ReceiverFeedScreen> createState() => _ReceiverFeedScreenState();
}

class _ReceiverFeedScreenState extends State<ReceiverFeedScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Calculates time remaining and flags urgent statuses
  Map<String, dynamic> _getExpiryContext(String createdAtString, int bestBeforeHours) {
    try {
      final DateTime createdAt = DateTime.parse(createdAtString).toLocal();
      final DateTime expiryTime = createdAt.add(Duration(hours: bestBeforeHours));
      final Duration difference = expiryTime.difference(DateTime.now());

      if (difference.isNegative) {
        return {"text": "Expired", "isUrgent": false, "isValid": false};
      }

      final int hours = difference.inHours;
      final int minutes = difference.inMinutes.remainder(60);

      if (hours == 0) {
        return {"text": "${minutes}m left! ⏳", "isUrgent": true, "isValid": true};
      }
      return {"text": "${hours}h ${minutes}m left", "isUrgent": false, "isValid": true};
    } catch (_) {
      return {"text": "N/A", "isUrgent": false, "isValid": false};
    }
  }

  // Prompts the NGO with collection modalities upon claiming
  // Prompts the NGO with collection modalities upon claiming
  Future<void> _claimFoodItem(BuildContext parentContext, String listingId, String title) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    bool isParcelConfirmed = false; // Initial state: unchecked

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: Text("Claim '$title'"),
        content: StatefulBuilder(
          builder: (BuildContext dialogFrameContext, StateSetter setDialogState) { // ✨ Changed parameter name to isolate context scope
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
                          // 1. Close the dialog layout immediately
                          Navigator.pop(dialogContext);

                          // 2. Fire off the cloud background transaction with parent view context
                          await FoodActionsService.executeClaimTransaction(
                            context: parentContext,
                            listingId: listingId,
                            deliveryType: 'self_pickup',
                            title: title,
                            onSuccess: () {
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
                          // 1. Close the dialog layout immediately
                          Navigator.pop(dialogContext);

                          // 2. Fire off the cloud background transaction with parent view context
                          await FoodActionsService.executeClaimTransaction(
                            context: parentContext,
                            listingId: listingId,
                            deliveryType: 'needs_volunteer',
                            title: title,
                            onSuccess: () {
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Available Surplus Food", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('food_listings')
            .stream(primaryKey: ['id'])
            .eq('status', 'available')
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.eco_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      "No active food listings nearby right now.\nCheck back shortly!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          final listings = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final item = listings[index];

              final String listingId = item['id'].toString();
              final String title = item['title'] ?? 'Surplus Food';
              final String caterer = item['caterer_name'] ?? 'Anonymous Donor';
              final String desc = item['items_description'] ?? '';
              final int servings = item['servings_count'] ?? 0;
              final double weight = double.tryParse(item['food_weight_kg']?.toString() ?? '0') ?? 0.0;
              final bool providesDelivery = item['provides_delivery'] ?? false;
              final double fee = double.tryParse(item['delivery_fee']?.toString() ?? '0') ?? 0.0;
              final String address = item['pickup_address'] ?? 'Address on claim';
              final String? imageUrl = item['image_url'];

              final String category = item['category'] ?? 'Veg';
              final String createdAt = item['created_at'] ?? DateTime.now().toIso8601String();
              final int bestBefore = item['best_before_hours'] ?? 4;

              final expiry = _getExpiryContext(createdAt, bestBefore);
              if (!expiry['isValid']) return const SizedBox.shrink();

              final bool isUrgent = expiry['isUrgent'];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: isUrgent ? 3 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isUrgent ? Colors.red.shade300 : Colors.grey.shade200,
                    width: isUrgent ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: imageUrl != null
                          ? Image.network(imageUrl, height: 140, width: double.infinity, fit: BoxFit.cover)
                          : Container(
                        height: 80,
                        width: double.infinity,
                        color: isUrgent ? Colors.red.shade50 : Colors.green.shade50,
                        child: Icon(
                            Icons.restaurant_menu,
                            size: 32,
                            color: isUrgent ? Colors.red.shade400 : Colors.green.shade400
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: category == 'Veg'
                                      ? Colors.green.shade50
                                      : (category == 'Non-Veg' ? Colors.red.shade50 : Colors.amber.shade50),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  category.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: category == 'Veg'
                                          ? Colors.green.shade800
                                          : (category == 'Non-Veg' ? Colors.red.shade800 : Colors.amber.shade800)
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isUrgent ? Colors.red.shade100 : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  expiry['text'],
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isUrgent ? Colors.red.shade900 : Colors.blue.shade800
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("by $caterer", style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic)),
                          const SizedBox(height: 8),

                          if (desc.isNotEmpty) ...[
                            Text(desc, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                            const SizedBox(height: 12),
                          ],

                          const Divider(),
                          const SizedBox(height: 4),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.people_outline, size: 18, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text("$servings servings", style: const TextStyle(fontWeight: FontWeight.w500)),
                                ],
                              ),
                              if (weight > 0)
                                Row(
                                  children: [
                                    const Icon(Icons.scale_outlined, size: 18, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text("${weight}kg est.", style: const TextStyle(fontWeight: FontWeight.w500)),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Icon(
                                  providesDelivery ? Icons.local_shipping_outlined : Icons.directions_walk_outlined,
                                  size: 18,
                                  color: providesDelivery ? Colors.blue : Colors.orange
                              ),
                              const SizedBox(width: 6),
                              Text(
                                providesDelivery ? "Donor Provides Delivery" : "Self-Pickup Required",
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: providesDelivery ? Colors.blue.shade700 : Colors.orange.shade800,
                                    fontSize: 13
                                ),
                              ),
                              const Spacer(),
                              Text(
                                fee > 0 ? "Fee: ₹${fee.toStringAsFixed(0)}" : "No Fees (Free)",
                                style: TextStyle(fontWeight: FontWeight.bold, color: fee > 0 ? Colors.black87 : Colors.green, fontSize: 13),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                    address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => _claimFoodItem(context, listingId, title),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isUrgent ? Colors.red.shade600 : Colors.green.shade600,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: const Text(
                                  "Claim Food Material",
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
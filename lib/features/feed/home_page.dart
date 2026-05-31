import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/food_details.dart';
import '../screens/profile_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../bookings/orders_screen.dart';
// 👇 LINKS DIRECTLY TO YOUR EMERGENCY HUB LAYER
import '../../widgets/emergency_hub_bottom_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _selectedCategory = "All";

  // Calculates live time remaining and flags urgent statuses (<1 hour left)
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

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
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
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Kolkata, India", style: TextStyle(color: Colors.grey, fontSize: 12)),
            Text("Anndaan", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: Color(0xFFB71C1C)),
            tooltip: "Emergency Safety Desk",
            onPressed: () {
              EmergencyHubBottomSheet.show(
                context,
                userRole: 'donor',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.black),
            onPressed: () {
              final mainNavState = context.findAncestorStateOfType<MainNavigationScreenState>();
              if (mainNavState != null) {
                mainNavState.setState(() {
                  mainNavState.currentIndex = 4; // Index 4 is your ProfileScreen
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Search Input Frame
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search for wedding leftovers...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Dynamic Category Horizontal Selector Filter Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ["All", "Veg", "Non-Veg", "Large Qty"].map((cat) {
                  final bool isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: Colors.green,
                      backgroundColor: Colors.grey[200],
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                      onSelected: (bool selected) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // LIVE REAL-TIME FOOD STREAM BUILDER
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('food_listings')
                  .stream(primaryKey: ['id'])
                  .eq('status', 'available')
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Center(child: CircularProgressIndicator(color: Colors.green)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState("No active food listings nearby right now.");
                }

                final allListings = snapshot.data!;

                final listings = allListings.where((item) {
                  if (_selectedCategory == "All") return true;

                  if (_selectedCategory == "Large Qty") {
                    final int servings = item['servings_count'] ?? 0;
                    final double weight = double.tryParse(item['food_weight_kg']?.toString() ?? '0') ?? 0.0;
                    return servings > 20 || weight > 10.0;
                  }

                  return item['category']?.toString() == _selectedCategory;
                }).toList();

                if (listings.isEmpty) {
                  return _buildEmptyState("No surplus food items listed matching this category.");
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final item = listings[index];

                    final String createdAt = item['created_at'] ?? DateTime.now().toIso8601String();
                    final int bestBefore = item['best_before_hours'] ?? 4;

                    final expiry = _getExpiryContext(createdAt, bestBefore);
                    if (!expiry['isValid']) return const SizedBox.shrink();

                    return FoodListingCard(
                      itemData: item,
                      expiryText: expiry['text'],
                      isUrgent: expiry['isUrgent'],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class FoodListingCard extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final String expiryText;
  final bool isUrgent;

  const FoodListingCard({
    super.key,
    required this.itemData,
    required this.expiryText,
    required this.isUrgent,
  });

  @override
  Widget build(BuildContext context) {
    final String title = itemData['title'] ?? 'Surplus Leftovers';
    final String caterer = itemData['caterer_name'] ?? 'Anonymous Donor';
    final String itemsDesc = itemData['items_description'] ?? 'No items listed';
    final int servings = itemData['servings_count'] ?? 0;
    final double weight = double.tryParse(itemData['food_weight_kg']?.toString() ?? '0') ?? 0.0;
    final double fee = double.tryParse(itemData['delivery_fee']?.toString() ?? '0') ?? 0.0;
    final String? imageUrl = itemData['image_url'];
    final bool providesDelivery = itemData['provides_delivery'] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      elevation: isUrgent ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: isUrgent
            ? BorderSide(color: Colors.red.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: imageUrl != null
                ? ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Image.network(imageUrl, fit: BoxFit.cover),
            )
                : Center(child: Icon(Icons.restaurant, size: 50, color: Colors.grey.shade400)),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text("Serves $servings+", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text("By $caterer", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),

                Text(
                    "Items: $itemsDesc",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13)
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      weight > 0 ? "⚖️ Weight: ${weight}kg est." : "⚖️ Weight: N/A",
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUrgent ? Colors.red.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "🕒 $expiryText",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isUrgent ? Colors.red.shade800 : Colors.blue.shade800
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                        providesDelivery ? Icons.local_shipping_outlined : Icons.directions_walk_outlined,
                        size: 16,
                        color: Colors.grey
                    ),
                    const SizedBox(width: 4),
                    Text(
                      providesDelivery ? "Delivery Provided" : "Self-Pickup Required",
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),

                const Divider(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        fee > 0 ? "Fee: ₹${fee.toStringAsFixed(0)}" : "Fee: Free",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)
                    ),
                    ElevatedButton(
                      // 🎉 UNBLOCKED ROUTE: Open details immediately for all users
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FoodDetails(
                              itemData: itemData,
                              expiryText: expiryText,
                              isUrgent: isUrgent,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isUrgent ? Colors.red.shade600 : Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("View Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
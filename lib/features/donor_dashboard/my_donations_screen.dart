import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 👇 CONNECTS TO YOUR RE-ARCHITECTED GLOBAL POLYMORPHIC REVIEW COMPONENT
import '../../widgets/review_bottom_sheet.dart';

class MyDonationsScreen extends StatelessWidget {
  const MyDonationsScreen({super.key});

  // 🔄 REUSABLE ROUTING HOOK: Launches custom targeting profiles on the global sheet
  void _openTargetReviewSheet({
    required BuildContext context,
    required String orderId,
    required String revieweeId,
    required PlatformRole revieweeRole,
    required String targetName,
  }) {
    ReviewBottomSheet.show(
      context,
      orderId: orderId,
      revieweeId: revieweeId,
      revieweeRole: revieweeRole,
      reviewerRole: PlatformRole.donor, // Active Reviewer is always the Donor
      targetName: targetName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Donations History", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('food_listings')
            .stream(primaryKey: ['id'])
            .eq('donor_id', user?.id ?? '')
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text("You haven't made any donations yet.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final listings = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final item = listings[index];

              final String orderId = item['id'].toString();
              final String status = item['status'] ?? 'available';
              final String deliveryType = item['delivery_type']?.toString() ?? 'needs_volunteer';
              final bool isSelfPickup = deliveryType == 'self_pickup';

              final String ngoId = item['receiver_id']?.toString() ?? '';
              final String ngoName = item['ngo_name']?.toString() ?? 'Recipient NGO';

              final String? volunteerId = item['volunteer_id']?.toString();
              final String volunteerName = item['volunteer_name']?.toString() ?? 'Rescue Driver';
              final bool hasVolunteer = volunteerId != null && volunteerId.trim().isNotEmpty;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade100)
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(item['title'] ?? 'Food Batch', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Servings: ${item['servings_count'] ?? '0'} • Tag: ${item['category'] ?? 'General'}"),
                        trailing: _buildStatusChip(status),
                      ),

                      // Contextual Action Engine triggered only when status is marked completed
                      if (status == 'completed') ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Divider(height: 12),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: Builder(
                            builder: (context) {
                              final bool hasReviewedNgo = item['has_reviewed_ngo'] ?? false;
                              final bool hasReviewedDriver = item['has_reviewed_volunteer'] ?? false;

                              if (!isSelfPickup && hasVolunteer) {
                                return Row(
                                  children: [
                                    // Left Button: NGO Target Lockout
                                    Expanded(
                                      child: hasReviewedNgo
                                          ? TextButton.icon(
                                        onPressed: null,
                                        icon: const Icon(Icons.check_circle_outline, color: Colors.grey, size: 16),
                                        label: const Text("NGO Rated", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                      )
                                          : OutlinedButton.icon(
                                        onPressed: () => _openTargetReviewSheet(
                                          context: context,
                                          orderId: orderId,
                                          revieweeId: ngoId,
                                          revieweeRole: PlatformRole.receiverNgo,
                                          targetName: ngoName,
                                        ),
                                        icon: const Icon(Icons.corporate_fare, color: Colors.green, size: 16),
                                        label: const Text(
                                          "Rate NGO",
                                          style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          side: const BorderSide(color: Colors.green, width: 1.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12), // Middle gutter separation space
                                    // Right Button: Logistics Driver Lockout
                                    Expanded(
                                      child: hasReviewedDriver
                                          ? TextButton.icon(
                                        onPressed: null,
                                        icon: const Icon(Icons.check_circle_outline, color: Colors.grey, size: 16),
                                        label: const Text("Driver Rated", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                      )
                                          : OutlinedButton.icon(
                                        onPressed: () => _openTargetReviewSheet(
                                          context: context,
                                          orderId: orderId,
                                          revieweeId: volunteerId,
                                          revieweeRole: PlatformRole.volunteer,
                                          targetName: volunteerName,
                                        ),
                                        icon: const Icon(Icons.local_shipping_outlined, color: Colors.blue, size: 16),
                                        label: const Text(
                                          "Rate Driver",
                                          style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          side: const BorderSide(color: Colors.blue, width: 1.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                // Fallback option: If it was a Direct Self-Pickup, show a clean wide action targeting only the NGO
                                return Align(
                                  alignment: Alignment.centerRight,
                                  child: hasReviewedNgo
                                      ? TextButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.check_circle, color: Colors.grey, size: 18),
                                    label: const Text("NGO Recipient Rated", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                  )
                                      : TextButton.icon(
                                    onPressed: () => _openTargetReviewSheet(
                                      context: context,
                                      orderId: orderId,
                                      revieweeId: ngoId,
                                      revieweeRole: PlatformRole.receiverNgo,
                                      targetName: ngoName,
                                    ),
                                    icon: const Icon(Icons.star_rate_rounded, color: Colors.green, size: 18),
                                    label: const Text(
                                      "Rate NGO Recipient",
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        )
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color labelColor = Colors.grey.shade600;
    Color bgColor = Colors.grey.shade100;

    if (status == 'available') {
      labelColor = Colors.green.shade700;
      bgColor = Colors.green.shade50;
    } else if (status == 'claimed' || status == 'assigned_to_volunteer') {
      labelColor = Colors.orange.shade700;
      bgColor = Colors.orange.shade50;
    } else if (status == 'in_transit') {
      labelColor = Colors.purple.shade700;
      bgColor = Colors.purple.shade50;
    } else if (status == 'completed') {
      labelColor = Colors.blue.shade700;
      bgColor = Colors.blue.shade50;
    } else if (status == 'expired' || status == 'cancelled') {
      labelColor = Colors.red.shade700;
      bgColor = Colors.red.shade50;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: labelColor,
        ),
      ),
    );
  }
}
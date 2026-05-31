import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 👇 LINKS DIRECTLY TO YOUR GLOBAL POLYMORPHIC REVIEW BOTTOM SHEET
import '../../widgets/review_bottom_sheet.dart';

class DonorPastRunsScreen extends StatelessWidget {
  const DonorPastRunsScreen({super.key});

  // 🍳 DONOR-TO-VOLUNTEER EVALUATION SHEET INVOCATION
  void _triggerDonorEvaluation(BuildContext context, Map<String, dynamic> listing) {
    final String orderId = listing['id'].toString();

    // Extracting driver/volunteer credentials linked to this food listing row
    final String volunteerId = listing['volunteer_id']?.toString() ?? '';
    final String volunteerName = listing['volunteer_name']?.toString() ?? 'Assigned Volunteer';

    if (volunteerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No volunteer was linked to this rescue operation to rate."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Opens up your beautifully styled global review bottom sheet instantly
    ReviewBottomSheet.show(
      context,
      orderId: orderId,
      revieweeId: volunteerId,
      revieweeRole: PlatformRole.volunteer, // Donor is evaluating the courier driver
      reviewerRole: PlatformRole.donor,
      targetName: volunteerName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Donation History", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('food_listings')
            .stream(primaryKey: ['id'])
            .eq('donor_id', user?.id ?? '') // Scopes directly to the active donor
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
                  Icon(Icons.storefront_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text("No donation history records found.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Filter completed or cancelled runs locally from the real-time stream snapshot
          final pastDonations = snapshot.data!.where((run) {
            final String status = run['status'] ?? '';
            return status == 'completed' || status == 'cancelled';
          }).toList();

          if (pastDonations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text("No finalized or completed runs found.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pastDonations.length,
            itemBuilder: (context, index) {
              final run = pastDonations[index];
              final String status = run['status'] ?? 'completed';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(run['title'] ?? 'Surplus Donation Batch', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Servings: ${run['servings_count'] ?? '0'} • Collected By: ${run['volunteer_name'] ?? 'Self-Pickup'}"),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'completed' ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: status == 'completed' ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                      // Only show the review handler button if the run was fully completed and a driver was attached
                      if (status == 'completed' && run['volunteer_id'] != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Divider(height: 12),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _triggerDonorEvaluation(context, run),
                              icon: const Icon(Icons.rate_review_rounded, color: Colors.green, size: 18),
                              label: const Text(
                                "Rate Dispatch Driver",
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ),
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
}
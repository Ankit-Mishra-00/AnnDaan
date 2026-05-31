import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 👇 LINKS DIRECTLY TO YOUR GLOBAL POLYMORPHIC REVIEW BOTTOM SHEET
import '../../widgets/review_bottom_sheet.dart';

class VolunteerPastRunsScreen extends StatelessWidget {
  const VolunteerPastRunsScreen({super.key});

  // 🍳 ADAPTIVE VOLUNTEER EVALUATION MATRIX
  void _triggerVolunteerEvaluation(BuildContext context, Map<String, dynamic> listing) {
    final String orderId = listing['id'].toString();

    final String donorId = listing['donor_id']?.toString() ?? '';
    final String donorName = listing['donor_name']?.toString() ?? 'Food Donor';

    final String ngoId = listing['receiver_id']?.toString() ?? '';
    final String ngoName = listing['ngo_name']?.toString() ?? 'Recipient NGO';

    // Show options to rate either party involved in the fulfillment chain
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Who would you like to evaluate?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.storefront, color: Colors.green),
              title: Text("Rate Donor ($donorName)"),
              subtitle: const Text("Evaluate food packaging, verification, and pickup location convenience."),
              onTap: () {
                Navigator.pop(sheetContext);
                ReviewBottomSheet.show(
                  context,
                  orderId: orderId,
                  revieweeId: donorId,
                  revieweeRole: PlatformRole.donor,
                  reviewerRole: PlatformRole.volunteer,
                  targetName: donorName,
                );
              },
            ),
            if (ngoId.isNotEmpty) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.corporate_fare, color: Colors.blue),
                title: Text("Rate NGO Recipient ($ngoName)"),
                subtitle: const Text("Evaluate drop-off coordination, offloading speed, and courtesy."),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ReviewBottomSheet.show(
                    context,
                    orderId: orderId,
                    revieweeId: ngoId,
                    revieweeRole: PlatformRole.receiverNgo,
                    reviewerRole: PlatformRole.volunteer,
                    targetName: ngoName,
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Past Logistics Runs", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('food_listings')
            .stream(primaryKey: ['id'])
            .eq('volunteer_id', user?.id ?? '')
        // 🔄 FIXED: Stream query sorts by timestamp cleanly without .inFilter constraints
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
                  Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text("No historical food logistics records found.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // ⚡ FIXED: Process the real-time collection cleanly using client-side logic
          final pastRuns = snapshot.data!.where((run) {
            final String status = run['status'] ?? '';
            return status == 'completed' || status == 'cancelled';
          }).toList();

          if (pastRuns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text("No completed or cancelled jobs found.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pastRuns.length,
            itemBuilder: (context, index) {
              final run = pastRuns[index];
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
                        title: Text(run['title'] ?? 'Food Rescue Run', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Weight: ${run['food_weight_kg'] ?? '0'} kg • Drop-off: ${run['ngo_name'] ?? 'Assigned NGO'}"),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'completed' ? Colors.blue.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: status == 'completed' ? Colors.blue.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                      if (status == 'completed') ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Divider(height: 12),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _triggerVolunteerEvaluation(context, run),
                              icon: const Icon(Icons.rate_review_rounded, color: Colors.green, size: 18),
                              label: const Text(
                                "Submit Handover Ratings",
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
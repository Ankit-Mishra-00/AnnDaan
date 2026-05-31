import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../volunteer/transit_hud_screen.dart';
import '../volunteer/volunteer_past_runs_screen.dart';
import '../../widgets/emergency_hub_bottom_sheet.dart';

class VolunteerDashboard extends StatelessWidget {
  const VolunteerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text("Volunteer Hub 🚗", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.shield_outlined, color: Color(0xFFB71C1C)),
              tooltip: "Emergency Safety Desk",
              onPressed: () {
                EmergencyHubBottomSheet.show(
                  context,
                  userRole: 'volunteer',
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.history_rounded, color: Colors.black87),
              tooltip: "Past Runs & Ratings",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VolunteerPastRunsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: "Available Runs"),
              Tab(text: "My Active Jobs"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildJobsStream(
              supabase,
              isHistoryView: false,
              currentUserId: user?.id ?? '',
            ),
            _buildJobsStream(
              supabase,
              isHistoryView: true,
              currentUserId: user?.id ?? '',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsStream(
      SupabaseClient supabase, {
        required bool isHistoryView,
        required String currentUserId,
      }) {
    final Stream<List<Map<String, dynamic>>> dbStream = supabase
        .from('food_listings')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: dbStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.green));
        }

        if (snapshot.hasError) {
          return Center(child: Text("Database Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }

        final listings = snapshot.data ?? [];
        List<Map<String, dynamic>> filteredJobs = [];

        if (isHistoryView) {
          filteredJobs = listings.where((job) {
            final String assignedDriver = job['volunteer_id']?.toString() ?? '';
            final String status = job['status']?.toString() ?? '';

            // 🌟 FIXED: Include ALL intermediate route tracking statuses so jobs do not disappear from this tab
            return assignedDriver == currentUserId &&
                (status == 'assigned_to_volunteer' ||
                    status == 'en_route_to_pickup' ||
                    status == 'arrived_at_pickup' ||
                    status == 'in_transit');
          }).toList();
        } else {
          filteredJobs = listings.where((job) {
            final String status = job['status']?.toString() ?? '';
            final String deliveryType = job['delivery_type']?.toString() ?? '';
            final String volunteerId = job['volunteer_id']?.toString() ?? '';

            bool isExpired = false;
            final String? createdAtString = job['created_at']?.toString();
            final int bestBeforeHours = int.tryParse(job['best_before_hours']?.toString() ?? '0') ?? 0;

            if (createdAtString != null && bestBeforeHours > 0) {
              final DateTime createdAt = DateTime.parse(createdAtString).toLocal();
              final DateTime expirationDeadline = createdAt.add(Duration(hours: bestBeforeHours));

              if (DateTime.now().isAfter(expirationDeadline)) {
                isExpired = true;
              }
            }

            return status == 'claimed' &&
                deliveryType == 'needs_volunteer' &&
                (volunteerId.isEmpty || job['volunteer_id'] == null) &&
                !isExpired &&
                status != 'expired';
          }).toList();
        }

        if (filteredJobs.isEmpty) {
          return _buildEmptyState(isHistoryView);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredJobs.length,
          itemBuilder: (context, index) {
            final job = filteredJobs[index];
            final String status = job['status']?.toString() ?? 'claimed';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            job['title'] ?? 'Food Rescue Run',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusChip(status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("📍 From: ${job['caterer_name'] ?? 'Donor location'}", style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text("🏢 To: ${job['pickup_address'] ?? 'Receiver location'}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const Divider(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (status == 'claimed') ? Colors.green : Colors.orange,
                        ),
                        icon: Icon(
                          status == 'claimed' ? Icons.assignment_outlined : Icons.local_shipping,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          if (status == 'claimed') {
                            // First time accepting: update to assigned state in DB
                            _updateJobStatus(context, supabase, job, 'assigned_to_volunteer');
                          } else {
                            // 🌟 FIXED: If already accepted, open the Transit HUD immediately.
                            // The HUD file will securely guide them through sequential milestone clicks.
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TransitHudScreen(deliveryJob: job),
                              ),
                            );
                          }
                        },
                        label: Text(
                          status == 'claimed' ? "Accept Route" : "Open Live Transit HUD",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateJobStatus(BuildContext context, SupabaseClient supabase, Map<String, dynamic> job, String nextStatus) async {
    final String jobId = job['id'].toString();

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final String? createdAtString = job['created_at']?.toString();
      final int bestBeforeHours = int.tryParse(job['best_before_hours']?.toString() ?? '0') ?? 0;

      if (createdAtString != null && bestBeforeHours > 0) {
        final DateTime createdAt = DateTime.parse(createdAtString).toLocal();
        final DateTime expirationDeadline = createdAt.add(Duration(hours: bestBeforeHours));

        if (DateTime.now().isAfter(expirationDeadline)) {
          await supabase.from('food_listings').update({'status': 'expired'}).eq('id', jobId);
          if (!context.mounted) return;
          _showExpiredAlert(context);
          return;
        }
      }

      final Map<String, dynamic> updatePayload = {'status': nextStatus};
      if (nextStatus == 'assigned_to_volunteer') {
        updatePayload['volunteer_id'] = user.id;
      }

      await supabase.from('food_listings').update(updatePayload).eq('id', jobId);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Route accepted successfully!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error accepting route: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

  void _showExpiredAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Batch Expired', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'This food listing has crossed its safety freshness limit and has been automatically cancelled. Thank you for your intent to help!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    String label = "Available";
    Color color = Colors.green;

    if (status == 'assigned_to_volunteer') { label = "Assigned"; color = Colors.orange; }
    if (status == 'en_route_to_pickup') { label = "En Route"; color = Colors.orangeAccent; }
    if (status == 'arrived_at_pickup') { label = "At Pickup"; color = Colors.purpleAccent; }
    if (status == 'in_transit') { label = "In Transit"; color = Colors.blue; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState(bool isHistoryView) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isHistoryView ? Icons.assignment_turned_in_outlined : Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(isHistoryView ? "No active delivery tasks" : "No pending delivery routes", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
        ],
      ),
    );
  }
}
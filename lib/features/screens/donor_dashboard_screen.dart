import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../donor_dashboard/UploadListingScreen.dart';
import '../donor_dashboard/post_food_screen.dart'; // Ensure this matches your file path
import '../screens/profile_screen.dart';

class DonorDashboardScreen extends StatefulWidget {
  const DonorDashboardScreen({super.key});

  @override
  State<DonorDashboardScreen> createState() => _DonorDashboardScreenState();
}

class _DonorDashboardScreenState extends State<DonorDashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fixed State Variable Declaration
  bool _isSignoutLoading = false;
  int _totalMealsSaved = 0;
  bool _isLoadingMetrics = true;

  @override
  void initState() {
    super.initState();
    _fetchRealMetricsData();
  }

  Future<void> _fetchRealMetricsData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase
          .from('food_listings')
          .select('servings_count')
          .eq('donor_id', user.id)
          .or('status.eq.claimed,status.eq.completed');

      int totalServings = 0;
      for (var record in response) {
        totalServings += (record['servings_count'] as num).toInt();
      }

      if (mounted) {
        setState(() {
          _totalMealsSaved = totalServings;
          _isLoadingMetrics = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching analytics metrics: $e");
      if (mounted) setState(() => _isLoadingMetrics = false);
    }
  }

  String _calculateRemainingTime(String createdAtString, int bestBeforeHours) {
    try {
      final DateTime createdAt = DateTime.parse(createdAtString).toLocal();
      final DateTime expiryTime = createdAt.add(Duration(hours: bestBeforeHours));
      final Duration difference = expiryTime.difference(DateTime.now());

      if (difference.isNegative) return "Expired";
      if (difference.inHours > 0) return "${difference.inHours}h ${difference.inMinutes.remainder(60)}m left";
      return "${difference.inMinutes}m left";
    } catch (_) {
      return "N/A";
    }
  }

  Future<void> _cancelListing(String listingId) async {
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Food Post?"),
        content: const Text("This will remove the listing from the public marketplace."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Keep")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Cancel", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await _supabase.from('food_listings').update({'status': 'cancelled'}).eq('id', listingId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Listing cancelled.")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Donor Dashboard", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.person_outline, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()))),
          _isSignoutLoading
              ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              setState(() => _isSignoutLoading = true);
              await _supabase.auth.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome back, ${user?.email?.split('@')[0] ?? 'Donor'}!", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Analytics Row
            Row(
              children: [
                _buildMetricCard("Meals Saved", _isLoadingMetrics ? "..." : "$_totalMealsSaved", Colors.green.shade50, Colors.green),
                const SizedBox(width: 12),
                _buildMetricCard("Status", "Active", Colors.orange.shade50, Colors.orange),
              ],
            ),
            const SizedBox(height: 25),

            // Post Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const DonorUploadScreen()));
                  _fetchRealMetricsData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.add_box, color: Colors.white),
                label: const Text("Post New Surplus Food", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),

            const Text("Your Active Listings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Listings Stream
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase.from('food_listings').stream(primaryKey: ['id']).eq('donor_id', user?.id ?? '').order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final listings = snapshot.data!;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final item = listings[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(item['title'] ?? 'Batch', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Status: ${item['status']}"),
                        trailing: item['status'] == 'available'
                            ? IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _cancelListing(item['id']))
                            : null,
                      ),
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

  Widget _buildMetricCard(String label, String value, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            Text(value, style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
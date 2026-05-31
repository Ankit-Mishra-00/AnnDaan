import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> _overrideOrderStatus(String orderId, String nextStatus) async {
    try {
      await supabase
          .from('food_listings')
          .update({'status': nextStatus})
          .eq('id', orderId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order #$orderId status forced to ${nextStatus.toUpperCase()} 🛠️"),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Override aborted: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showStatusOverrideSheet(BuildContext context, Map<String, dynamic> log) {
    final String orderId = log['id'].toString();
    final String currentStatus = log['status'] ?? 'available';

    final List<String> statusOptions = [
      'available',
      'claimed',
      'assigned_to_volunteer',
      'in_transit',
      'completed',
      'cancelled',
      'expired'
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Modify Order Status: #$orderId",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Batch Title: ${log['title'] ?? 'Food Batch'}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 24),
              const Text(
                "Select System Override Target State:",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: statusOptions.length,
                  itemBuilder: (context, index) {
                    final target = statusOptions[index];
                    final bool isCurrent = target == currentStatus;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onTap: isCurrent ? null : () => _overrideOrderStatus(orderId, target),
                      title: Text(
                        target.toUpperCase(),
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? Colors.green : Colors.black87,
                        ),
                      ),
                      leading: Icon(
                        isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isCurrent ? Colors.green : Colors.grey,
                        size: 18,
                      ),
                      trailing: isCurrent
                          ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                        child: const Text("ACTIVE", style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold)),
                      )
                          : Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Central Control Panel",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminUsersScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            tooltip: 'Sign Out Safely',
            onPressed: () async {
              await supabase.auth.signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✨ NEW: Dynamic Verification Queue Alert Banner
            _buildVerificationAlertBanner(),
            const SizedBox(height: 16),

            const Text(
              "System Ecosystem Metrics",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _buildMetricGrid(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Global Ledger Audit Trail",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Text(
                  "Tap log row to edit status",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildGlobalAuditStream(),
          ],
        ),
      ),
    );
  }

  // Helper widget to look for pending clearance requests
  Widget _buildVerificationAlertBanner() {
    return FutureBuilder<PostgrestResponse>(
      // Count profiles where is_verified is false, excluding admins
      future: supabase
          .from('profiles')
          .select('id')
          .eq('is_verified', false)
          .neq('role', 'admin')
          .count(CountOption.exact),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();

        final int pendingCount = snapshot.data!.count;
        if (pendingCount == 0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminUsersScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.gavel_rounded, color: Colors.amber.shade900, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Verification Action Required",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber.shade900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "There are $pendingCount profiles waiting for clearance registration approval.",
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.amber.shade900),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase.from('food_listings').select('status'),
      builder: (context, snapshot) {
        int total = 0;
        int active = 0;
        int completed = 0;

        if (snapshot.hasData && snapshot.data != null) {
          final list = snapshot.data!;
          total = list.length;
          active = list.where((row) => ['claimed', 'assigned_to_volunteer', 'in_transit'].contains(row['status'])).length;
          completed = list.where((row) => row['status'] == 'completed').length;
        }

        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            _metricCard("Total Batches", total.toString(), Colors.blue, Icons.inventory_2_outlined),
            _metricCard("In Transit", active.toString(), Colors.orange, Icons.local_shipping_outlined),
            _metricCard("Completed", completed.toString(), Colors.green, Icons.check_circle_outline),
          ],
        );
      },
    );
  }

  Widget _metricCard(String title, String count, Color themeColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: themeColor, size: 20),
          const SizedBox(height: 8),
          Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildGlobalAuditStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('food_listings').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator(color: Colors.green)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text("No global transactions found in ledger.", style: TextStyle(color: Colors.grey))),
          );
        }

        final masterList = snapshot.data!;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: masterList.length,
          itemBuilder: (context, index) {
            final log = masterList[index];
            final String status = log['status'] ?? 'available';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    onTap: () => _showStatusOverrideSheet(context, log),
                    title: Text(
                      log['title'] ?? 'Food Batch Bundle',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Donor: ${log['caterer_name'] ?? 'Unknown'} ➔ NGO: ${log['ngo_name'] ?? 'Unclaimed'}",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _adminStatusChip(status),
                        const SizedBox(height: 4),
                        Text(
                          "ID: #${log['id']}",
                          style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontFamily: 'monospace'),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _adminStatusChip(String status) {
    Color color = Colors.grey;
    if (status == 'completed') color = Colors.green;
    if (status == 'in_transit') color = Colors.purple;
    if (status == 'claimed' || status == 'assigned_to_volunteer') color = Colors.orange;
    if (status == 'available') color = Colors.blue;
    if (status == 'cancelled' || status == 'expired') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        // ✨ FIXED: Replaced corrupted withValues API fallback matrix with clean opacity scaling
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
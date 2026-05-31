import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _toggleVerification(String userId, bool currentStatus) async {
    try {
      final targetNextState = !currentStatus;

      await supabase
          .from('profiles')
          .update({'is_verified': targetNextState})
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(targetNextState ? "User successfully verified! ✨" : "User verification revoked."),
            backgroundColor: targetNextState ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint("SUPABASE RLS/DB ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Database update failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
      return false;
    }
  }

  // 🛡️ ENHANCED: Deep Metadata Profile Inspection Sheet
  void _showUserProfileInspectionSheet(BuildContext context, Map<String, dynamic> profile, String targetRole) {
    final String uId = profile['id'].toString();
    final String email = profile['email'] ?? 'No email logged';
    final String name = profile['name'] ?? profile['full_name'] ?? profile['display_name'] ?? 'Not Provided Yet';
    final String phone = profile['phone_number'] ?? profile['phone'] ?? 'No phone logged';
    final bool isVerified = profile['is_verified'] ?? false;
    final String createdAt = profile['created_at'] != null
        ? DateTime.parse(profile['created_at'].toString()).toLocal().toString().substring(0, 16)
        : 'Unknown Date';

    // ✨ NEW: Role-Specific Core Security Fields
    final String orgName = profile['organization_name'] ?? 'Not Listed';
    final String govId = profile['government_id'] ?? 'Pending Upload';
    final String address = profile['physical_address'] ?? 'No Address Provided';
    final String license = profile['license_number'] ?? 'No License Registered';
    final String vehicle = profile['vehicle_type'] ?? 'Unspecified';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows layout to scale beautifully if fields are large
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollController) => SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Verify Credentials", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                          child: Text(targetRole.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                        )
                      ],
                    ),
                    const Divider(height: 24),

                    // Section A: Baseline Profile Matrix
                    const Text("PRIMARY ACCOUNT DETAILS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _infoRow("Registered Name", name),
                    _infoRow("Account Email", email),
                    _infoRow("Contact Phone", phone),
                    _infoRow("Joined System", createdAt),
                    _infoRow("Unique User ID", uId, isMonospace: true),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(),
                    ),

                    // Section B: Contextual Security Verification Layout
                    const Text("LEGAL & LOGISTICS CLEARANCE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                    const SizedBox(height: 12),

                    if (targetRole == 'receiver') ...[
                      _infoRow("Organization", orgName),
                      _infoRow("Govt Reg Code / Tax ID", govId, isMonospace: true),
                      _infoRow("Dropoff Address", address),
                    ],

                    if (targetRole == 'volunteer') ...[
                      _infoRow("Driver License", license, isMonospace: true),
                      _infoRow("Transport Vehicle", vehicle),
                    ],

                    if (targetRole == 'donor') ...[
                      _infoRow("Company/Facility", orgName),
                      _infoRow("Food Safety ID (FSSAI)", govId, isMonospace: true),
                      _infoRow("Pickup Address", address),
                    ],

                    const Divider(height: 28),

                    // Section C: Decision Actions Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Grant Platform Access", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              isVerified ? "Approved: User active on maps" : "Restricted: Blocked from actions",
                              style: TextStyle(fontSize: 12, color: isVerified ? Colors.green : Colors.redAccent, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Switch(
                          value: isVerified,
                          activeColor: Colors.green,
                          onChanged: (bool value) async {
                            final isSuccess = await _toggleVerification(uId, isVerified);
                            if (isSuccess && sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(String label, String value, {bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Ecosystem Directories", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "Volunteers 🚙"),
            Tab(text: "NGO Receivers 🏢"),
            Tab(text: "Donors 🍳"),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase.from('profiles').stream(primaryKey: ['id']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          final allProfiles = snapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildUserList(allProfiles, 'volunteer'),
              _buildUserList(allProfiles, 'receiver'),
              _buildUserList(allProfiles, 'donor'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> masterList, String targetRole) {
    final List<Map<String, dynamic>> users = masterList
        .where((profile) => profile['role']?.toString().toLowerCase() == targetRole)
        .toList();

    users.sort((a, b) {
      final bool aVerified = a['is_verified'] == true;
      final bool bVerified = b['is_verified'] == true;
      if (!aVerified && bVerified) return -1;
      if (aVerified && !bVerified) return 1;
      return 0;
    });

    if (users.isEmpty) {
      return Center(
        child: Text("No registered ${targetRole}s found.", style: const TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final profile = users[index];

        final String displayName = profile['organization_name'] ?? profile['name'] ?? profile['full_name'] ?? profile['display_name'] ?? profile['email'] ?? 'Unnamed Profile';
        final String details = profile['phone_number'] ?? profile['phone'] ?? profile['email'] ?? 'No contact paths registered';
        final bool isVerified = profile['is_verified'] ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isVerified ? Colors.grey.shade200 : Colors.red.shade100, width: 1.5),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            onTap: () => _showUserProfileInspectionSheet(context, profile, targetRole),
            leading: CircleAvatar(
              backgroundColor: isVerified ? Colors.green.shade50 : Colors.red.shade50,
              child: Icon(
                targetRole == 'volunteer' ? Icons.local_shipping : (targetRole == 'receiver' ? Icons.corporate_fare : Icons.storefront),
                color: isVerified ? Colors.green : Colors.redAccent,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                    isVerified ? Icons.verified : Icons.warning_amber_rounded,
                    color: isVerified ? Colors.blue : Colors.redAccent,
                    size: 16
                ),
              ],
            ),
            subtitle: Text(details, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: Icon(Icons.assignment_ind_outlined, color: isVerified ? Colors.grey.shade400 : Colors.redAccent.withOpacity(0.7)),
          ),
        );
      },
    );
  }
}
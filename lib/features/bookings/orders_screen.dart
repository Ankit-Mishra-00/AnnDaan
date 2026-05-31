import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/review_bottom_sheet.dart';
import '../screens/login_screen.dart';
import '../../widgets/verification_upload_screen.dart';

class OrdersScreen extends StatefulWidget {
  final String receiverId;

  const OrdersScreen({
    super.key,
    required this.receiverId,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;

  void openTargetReviewSheet({
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
      reviewerRole: PlatformRole.receiverNgo,
      targetName: targetName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    // 🚪 STEP 1: GUEST INTERCEPTION - No User Exists
    // 🔥 Clean layout: Removed the redundant, breaking sign-out button entirely!
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("My Bookings", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.lock_outline_rounded, size: 48, color: Colors.green),
              ),
              const SizedBox(height: 24),
              const Text(
                "Authentication Required",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              const Text(
                "You are currently exploring as a guest. Please sign up or log into an existing account to track claimed food items and active delivery runs.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: const Text("Login / Sign Up", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 🔐 STEP 2: VERIFICATION STREAM INTERCEPTOR WALL (User is Logged In)
    return StreamBuilder<Map<String, dynamic>>(
      stream: supabase.from('profiles').stream(primaryKey: ['id']).eq('id', user.id).map((list) => list.first),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text("My Bookings", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: const Center(child: CircularProgressIndicator(color: Colors.green)),
          );
        }

        final profile = profileSnapshot.data;
        final bool isVerified = profile?['is_verified'] ?? false;
        final String? existingAddress = profile?['physical_address']?.toString();
        final bool hasSubmittedDocs = existingAddress != null && existingAddress.trim().isNotEmpty;

        // 🚧 STEP 3: ACCOUNT RESTRICTED - Unverified User State
        if (!isVerified) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text("My Bookings", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: hasSubmittedDocs ? Colors.orange.shade50 : Colors.grey.shade50,
                          shape: BoxShape.circle
                      ),
                      child: Icon(
                          hasSubmittedDocs ? Icons.gpp_maybe_rounded : Icons.contact_page_outlined,
                          size: 64,
                          color: hasSubmittedDocs ? Colors.orange : Colors.grey
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      hasSubmittedDocs ? "Verification Pending" : "Verification Required",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasSubmittedDocs
                          ? "Your platform profile credentials are submitted. Our ecosystem management operators are verifying your standing files to open logistics routing."
                          : "Before tracking active logistics operations, you must upload your formal organizational credentials for background safety clearance.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, height: 1.4, fontSize: 13),
                    ),
                    const SizedBox(height: 32),

                    if (hasSubmittedDocs) ...[
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 32),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 18),
                          label: const Text("Complete Verification Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const VerificationUploadScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 🛡️ EMERGENCY SIGN OUT - Now fully protected against session absence errors
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.black54),
                      label: const Text("Sign Out to Guest Mode", style: TextStyle(color: Colors.black87, fontSize: 13)),
                      onPressed: () async {
                        try {
                          // 1. Attempt a standard clean network sign-out
                          await supabase.auth.signOut();
                        } catch (e) {
                          debugPrint("Server session already gone, forcing local eviction: $e");

                          // 2. FORCE EVICTION: If the server rejects the token, manually clear
                          // the local session state so the app immediately flips back to Guest Mode.
                          // This forces the stream/user listener to reset to null.
                          supabase.auth.setSession("");
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 🎉 STEP 4: VERIFICATION APPROVED - Expose standard operative tabs
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text("My Bookings", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              backgroundColor: Colors.white,
              elevation: 0,
              bottom: const TabBar(
                labelColor: Colors.green,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.green,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: "Active Claims 🚚"),
                  Tab(text: "Past History 📂"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildClaimsStream(const ['claimed', 'assigned_to_volunteer', 'en_route_to_pickup', 'arrived_at_pickup', 'in_transit']),
                _buildClaimsStream(const ['completed', 'expired', 'cancelled']),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClaimsStream(List<String> statusScope) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('food_listings')
          .stream(primaryKey: ['id'])
          .eq('receiver_id', widget.receiverId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.green));
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error fetching ledger: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }

        final rawListings = snapshot.data ?? [];
        final claims = rawListings.where((element) => statusScope.contains(element['status']?.toString())).toList();

        if (claims.isEmpty) {
          return _buildNoOrdersPlaceholder();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: claims.length,
          itemBuilder: (context, index) {
            final item = claims[index];

            final String orderId = item['id'].toString();
            final String title = item['title']?.toString() ?? 'Surplus Leftovers';
            final String caterer = item['caterer_name']?.toString() ?? 'Anonymous Donor';
            final String donorId = item['donor_id']?.toString() ?? '';
            final String address = item['pickup_address']?.toString() ?? 'Address details inside profile';
            final String status = item['status']?.toString() ?? 'claimed';
            final String deliveryType = item['delivery_type']?.toString() ?? 'needs_volunteer';

            final String? volunteerId = item['volunteer_id']?.toString();
            final String volunteerName = item['volunteer_name'] ?? 'Transport Driver';

            double fee = 0.0;
            if (item['delivery_fee'] != null) {
              fee = double.tryParse(item['delivery_fee'].toString()) ?? 0.0;
            }

            final bool isSelfPickup = deliveryType == 'self_pickup';
            final bool isDriverInTransit = status == 'in_transit';
            final bool hasVolunteer = volunteerId != null && volunteerId.trim().isNotEmpty;
            final bool canComplete = isSelfPickup || isDriverInTransit || status == 'arrived_at_pickup';
            final bool isActiveTab = !const ['completed', 'expired', 'cancelled'].contains(status);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade100, width: 1),
              ),
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
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusChip(status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("From: $caterer", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          fee > 0 ? "₹${fee.toStringAsFixed(0)} Paid" : "Free",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),

                    if (isActiveTab) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: Icon(
                            isDriverInTransit ? Icons.local_shipping : Icons.check_circle_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            isDriverInTransit
                                ? "Driver In Transit - Confirm Handover"
                                : (hasVolunteer ? "Awaiting Driver Collection" : "Confirm Safe Collection"),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDriverInTransit ? Colors.orange : (canComplete ? Colors.green : Colors.grey.shade400),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: !canComplete ? null : () async {
                            final currentContext = context;
                            try {
                              await supabase.from('food_listings').update({'status': 'completed'}).eq('id', orderId);

                              if (!currentContext.mounted) return;

                              openTargetReviewSheet(
                                context: currentContext,
                                orderId: orderId,
                                revieweeId: donorId,
                                revieweeRole: PlatformRole.donor,
                                targetName: caterer,
                              );
                            } catch (e) {
                              if (currentContext.mounted) {
                                ScaffoldMessenger.of(currentContext).showSnackBar(
                                  SnackBar(content: Text("Error completing handover: $e"), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],

                    if (!isActiveTab && status == 'completed') ...[
                      const SizedBox(height: 16),
                      const Divider(color: Colors.black12, height: 1),
                      const SizedBox(height: 12),

                      if (hasVolunteer) ...[
                        Builder(
                            builder: (context) {
                              final bool hasReviewedKitchen = item['has_reviewed_donor'] ?? false;
                              final bool hasReviewedDriver = item['has_reviewed_volunteer'] ?? false;

                              return Row(
                                children: [
                                  Expanded(
                                    child: hasReviewedKitchen
                                        ? const TextButton(
                                      onPressed: null,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_outline, color: Colors.grey, size: 16),
                                          SizedBox(width: 4),
                                          Text("Kitchen Rated", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                        ],
                                      ),
                                    )
                                        : OutlinedButton.icon(
                                      onPressed: () => openTargetReviewSheet(
                                        context: context,
                                        orderId: orderId,
                                        revieweeId: donorId,
                                        revieweeRole: PlatformRole.donor,
                                        targetName: caterer,
                                      ),
                                      icon: const Icon(Icons.storefront, color: Colors.green, size: 16),
                                      label: const Text("Rate Kitchen", style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: const BorderSide(color: Colors.green, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: hasReviewedDriver
                                        ? const TextButton(
                                      onPressed: null,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_outline, color: Colors.grey, size: 16),
                                          SizedBox(width: 4),
                                          Text("Driver Rated", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                        ],
                                      ),
                                    )
                                        : OutlinedButton.icon(
                                      onPressed: () => openTargetReviewSheet(
                                        context: context,
                                        orderId: orderId,
                                        revieweeId: volunteerId,
                                        revieweeRole: PlatformRole.volunteer,
                                        targetName: volunteerName,
                                      ),
                                      icon: const Icon(Icons.local_shipping_outlined, color: Colors.blue, size: 16),
                                      label: const Text("Rate Driver", style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: const BorderSide(color: Colors.blue, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                        ),
                      ] else ...[
                        Builder(
                            builder: (context) {
                              final bool hasReviewedDonorDirect = item['has_reviewed_donor'] ?? false;

                              return Align(
                                alignment: Alignment.centerRight,
                                child: hasReviewedDonorDirect
                                    ? TextButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.check_circle, color: Colors.grey, size: 16),
                                  label: const Text("Food Donor Rated", style: TextStyle(color: Colors.grey)),
                                )
                                    : TextButton.icon(
                                  onPressed: () => openTargetReviewSheet(
                                    context: context,
                                    orderId: orderId,
                                    revieweeId: donorId,
                                    revieweeRole: PlatformRole.donor,
                                    targetName: caterer,
                                  ),
                                  icon: const Icon(Icons.rate_review_outlined, size: 16, color: Colors.green),
                                  label: const Text("Review Food Donor", style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                              );
                            }
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusChip(String status) {
    String displayLabel = "Pending Collection";
    Color labelColor = Colors.orange;
    Color bgColor = Colors.orange.shade50;

    if (status == 'assigned_to_volunteer') {
      displayLabel = "Driver Assigned";
      labelColor = Colors.blue;
      bgColor = Colors.blue.shade50;
    } else if (status == 'en_route_to_pickup') {
      displayLabel = "Driver Heading to Donor";
      labelColor = Colors.blueGrey;
      bgColor = Colors.blueGrey.shade50;
    } else if (status == 'arrived_at_pickup') {
      displayLabel = "Driver Processing Cargo";
      labelColor = Colors.teal;
      bgColor = Colors.teal.shade50;
    } else if (status == 'in_transit') {
      displayLabel = "On The Way 🚗";
      labelColor = Colors.purple;
      bgColor = Colors.purple.shade50;
    } else if (status == 'completed') {
      displayLabel = "Completed";
      labelColor = Colors.green;
      bgColor = Colors.green.shade50;
    } else if (status == 'cancelled' || status == 'expired') {
      displayLabel = status.toUpperCase();
      labelColor = Colors.red;
      bgColor = Colors.red.shade50;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(
        displayLabel,
        style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildNoOrdersPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              "You have no bookings yet",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            const Text(
              "Head over to the home feed to find and claim surplus food batches nearby.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
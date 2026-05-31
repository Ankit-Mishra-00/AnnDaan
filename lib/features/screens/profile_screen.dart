import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_gate.dart';
import '../donor_dashboard/my_donations_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/reviews_list_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Future<Map<String, dynamic>?>? _profileFuture;
  Future<Map<String, dynamic>>? _ratingFuture;

  @override
  void initState() {
    super.initState();
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _profileFuture = _fetchProfileData();
      _ratingFuture = _fetchLiveRatingMetrics(user.id);
    }
  }

  // Helper method to completely refresh screen profile metrics from database
  void _refreshProfileMetrics() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _profileFuture = _fetchProfileData();
        _ratingFuture = _fetchLiveRatingMetrics(user.id);
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchProfileData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
  }

  Future<Map<String, dynamic>> _fetchLiveRatingMetrics(String userId) async {
    try {
      final List<Map<String, dynamic>> reviewRows = await _supabase
          .from('reviews')
          .select('rating')
          .eq('reviewee_id', userId);

      if (reviewRows.isEmpty) {
        return {'avg': '5.0', 'count': 0};
      }

      double totalStars = 0;
      for (var row in reviewRows) {
        totalStars += (row['rating'] as num).toDouble();
      }
      double average = totalStars / reviewRows.length;

      return {
        'avg': average.toStringAsFixed(1),
        'count': reviewRows.length,
      };
    } catch (e) {
      debugPrint("Rating fetch fallback: $e");
      return {'avg': '5.0', 'count': 0};
    }
  }

  Future<void> _performLogout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: CircularProgressIndicator(color: Colors.green),
      ),
    );

    try {
      if (mounted) {
        Navigator.of(context).pop();
      }

      await _supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
            (route) => false,
      );

    } catch (e) {
      if (mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logout failed: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Profile"), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_circle_outlined, size: 80, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  "Join Anndaan Today!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Log in or create an account to view your impact stats, manage your donations, track bookings, and earn Green Points.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthGate()),
                            (route) => false,
                      );
                    },
                    child: const Text("Log In / Sign Up", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Profile"), centerTitle: true),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 60, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      "Profile data not synchronized yet.",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Please complete your configuration settings or re-authenticate your session.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _performLogout,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text("Sign Out Safely", style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              ),
            );
          }

          final userData = snapshot.data!;
          final String name = userData['full_name'] ?? 'User';
          final String bio = userData['bio'] ?? 'Dedicated to reducing food waste.';
          final String location = userData['address_text'] ?? 'Location Unassigned';
          final String role = userData['role'] ?? 'donor';

          final int points = userData['green_points'] ?? 0;
          final int listingsPosted = userData['listings_posted'] ?? 0;

          // 🔄 FIXED: Unified extraction parameters point straight to total_weight_saved_kg for everyone
          final double generalWeightMetric = (userData['total_weight_saved_kg'] ?? 0.0).toDouble();

          return Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 50,
                backgroundImage: userData['avatar_url'] != null
                    ? NetworkImage(userData['avatar_url'])
                    : null,
                child: userData['avatar_url'] == null ? const Icon(Icons.person, size: 50) : null,
              ),
              const SizedBox(height: 10),
              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(location, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 40.0, vertical: 8.0), child: Divider()),
              Text(bio, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey), textAlign: TextAlign.center),
              const SizedBox(height: 20),

              FutureBuilder<Map<String, dynamic>>(
                  future: _ratingFuture,
                  builder: (context, ratingSnapshot) {
                    final String liveRating = ratingSnapshot.data?['avg'] ?? '5.0';

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStat("$points 🌟", "Green Points"),
                        if (role == 'volunteer') ...[
                          // 🔄 FIXED: Reading directly from the verified database metric column
                          _buildStat("${generalWeightMetric.toStringAsFixed(1)} kg 🍃", "Weight Rescued"),
                          _buildStat("$liveRating ⭐", "Driver Rating"),
                        ] else if (role == 'donor') ...[
                          _buildStat("$liveRating ⭐", "Avg Rating"),
                          _buildStat("$listingsPosted 🍽️", "Listings Posted"),
                          _buildStat("${generalWeightMetric.toStringAsFixed(1)} kg 🏢", "Total Donated"),
                        ] else ...[
                          _buildStat("4 🎒", "Claims Claimed"),
                          _buildStat("Receiver", "Role"),
                        ],
                      ],
                    );
                  }
              ),
              const Divider(height: 40),

              Expanded(
                child: ListView(
                  children: [
                    if (role == 'volunteer')
                      _buildMenuItem(Icons.local_shipping_outlined, "My Deliveries", () {
                        final mainNavState = context.findAncestorStateOfType<MainNavigationScreenState>();
                        if (mainNavState != null) {
                          mainNavState.setState(() => mainNavState.currentIndex = 2);
                        }
                        _refreshProfileMetrics();
                      }),

                    if (role == 'receiver')
                      _buildMenuItem(Icons.favorite_border, "My Bookings", () {
                        final mainNavState = context.findAncestorStateOfType<MainNavigationScreenState>();
                        if (mainNavState != null) {
                          mainNavState.setState(() => mainNavState.currentIndex = 2);
                        }
                        _refreshProfileMetrics();
                      }),

                    if (role == 'donor')
                      _buildMenuItem(Icons.card_giftcard, "My Donations History", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MyDonationsScreen()),
                        ).then((_) {
                          _refreshProfileMetrics();
                        });
                      }),

                    _buildMenuItem(Icons.star_border, "My Reviews", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReviewsListScreen(
                            userId: userData['id'],
                            userName: userData['full_name'] ?? 'User',
                          ),
                        ),
                      ).then((_) => _refreshProfileMetrics());
                    }),
                    _buildMenuItem(Icons.settings, "Settings", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      ).then((_) => _refreshProfileMetrics());
                    }),
                    _buildMenuItem(
                      Icons.logout,
                      "Logout",
                      _performLogout,
                      textColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {Color textColor = Colors.black}) {
    return ListTile(
      leading: Icon(icon, color: textColor == Colors.red ? Colors.red : Colors.grey.shade700),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: textColor == Colors.red ? Colors.red.withAlpha(100) : Colors.grey),
      onTap: onTap,
    );
  }
}
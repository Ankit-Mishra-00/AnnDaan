import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bookings/orders_screen.dart';
import '../feed/home_page.dart';
import '../donor_dashboard/my_donations_screen.dart';
import '../volunteer/volunteer_dashboard.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;
  final SupabaseClient _supabase = Supabase.instance.client;
  String _userRole = 'guest'; // Default to guest
  bool _isLoadingRole = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeUserSession();
  }

  Future<void> _initializeUserSession() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _userRole = 'guest';
        _isLoadingRole = false;
      });
      return;
    }
    _checkUserRole(user.id);
  }

  Future<void> _checkUserRole(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _userRole = data['role']?.toString().toLowerCase().trim() ?? 'receiver';
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRole = false;
          _errorMessage = "Failed to load profile. Please check connection.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              ElevatedButton(onPressed: () => _supabase.auth.signOut(), child: const Text("Sign Out")),
            ],
          ),
        ),
      );
    }

    final List<Widget> screens = [];
    final List<BottomNavigationBarItem> navItems = [];

    // Role-based routing matrix
    switch (_userRole) {
      case 'admin':
        screens.addAll([const Center(child: Text("Admin Console")), const ProfileScreen()]);
        navItems.addAll([
          const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: "Console"),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ]);
        break;

      case 'volunteer':
        screens.addAll([const VolunteerDashboard(), const ProfileScreen()]);
        navItems.addAll([
          const BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: "Deliveries"),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ]);
        break;

      case 'donor':
        screens.addAll([const HomePage(), const MyDonationsScreen(), const ProfileScreen()]);
        navItems.addAll([
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          const BottomNavigationBarItem(icon: Icon(Icons.fastfood), label: "My Donations"),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ]);
        break;

      case 'guest':
        screens.addAll([const HomePage(), const ProfileScreen()]);
        navItems.addAll([
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Browse"),
          const BottomNavigationBarItem(icon: Icon(Icons.login), label: "Login/Profile"),
        ]);
        break;

      case 'receiver':
      default:
        screens.addAll([
          const HomePage(),
          OrdersScreen(receiverId: _supabase.auth.currentUser?.id ?? ''),
          const ProfileScreen(),
        ]);
        navItems.addAll([
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: "Bookings"),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ]);
        break;
    }

    if (currentIndex >= screens.length) currentIndex = 0;

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        onTap: (index) => setState(() => currentIndex = index),
        items: navItems,
      ),
    );
  }
}
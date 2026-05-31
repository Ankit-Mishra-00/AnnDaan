import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum PlatformRole { donor, receiverNgo, volunteer }

class ReviewBottomSheet extends StatefulWidget {
  final String orderId;
  final String revieweeId;
  final PlatformRole revieweeRole;
  final PlatformRole reviewerRole;
  final String targetName;

  const ReviewBottomSheet({
    super.key,
    required this.orderId,
    required this.revieweeId,
    required this.revieweeRole,
    required this.reviewerRole,
    required this.targetName,
  });

  static void show(
      BuildContext context, {
        required String orderId,
        required String revieweeId,
        required PlatformRole revieweeRole,
        required PlatformRole reviewerRole,
        required String targetName,
      }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141916),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ReviewBottomSheet(
          orderId: orderId,
          revieweeId: revieweeId,
          revieweeRole: revieweeRole,
          reviewerRole: reviewerRole,
          targetName: targetName,
        ),
      ),
    );
  }

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();
  int _selectedRating = 0;
  bool _isSubmitting = false;

  // ⚡ HELPER METHOD: Converts Dart camelCase enums to Postgres snake_case strings safely
  String _getDbRoleString(PlatformRole role) {
    if (role == PlatformRole.receiverNgo) {
      return 'receiver_ngo';
    }
    return role.name;
  }

  @override
  void initState() {
    super.initState();
    _checkForExistingReview();
  }

  Future<void> _checkForExistingReview() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // 🔄 FIXED: Query checks using the sanitized database-friendly string
      final data = await _supabase
          .from('reviews')
          .select('rating, comment')
          .eq('listing_id', widget.orderId)
          .eq('reviewer_id', currentUserId)
          .eq('reviewee_role', _getDbRoleString(widget.revieweeRole))
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _selectedRating = data['rating'] as int;
          if (data['comment'] != null) {
            _commentController.text = data['comment'].toString();
          }
        });
      }
    } catch (e) {
      debugPrint("Error pre-fetching review: $e");
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating before submitting.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw 'User session invalid. Please log in again.';

      debugPrint("🚀 SUBMITTING REVIEW PAYLOAD:");
      debugPrint("Listing ID: ${widget.orderId}");
      debugPrint("Reviewer ID: $currentUserId");
      debugPrint("Reviewee ID: ${widget.revieweeId}");
      debugPrint("Rating: $_selectedRating");

      // 🔄 FIXED: Roles are now mapped dynamically via _getDbRoleString() to prevent enum input type crashing (22P02)
      await _supabase.from('reviews').upsert({
        'listing_id': widget.orderId,
        'reviewer_id': currentUserId,
        'reviewee_id': widget.revieweeId,
        'rating': _selectedRating,
        'comment': _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        'reviewer_role': _getDbRoleString(widget.reviewerRole),
        'reviewee_role': _getDbRoleString(widget.revieweeRole),
      }, onConflict: 'listing_id, reviewer_id, reviewee_role');

      debugPrint("✅ DATABASE TRANSACTION SUCCESSFUL (UPSERTED)!");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Review logged successfully!'),
              backgroundColor: Color(0xFF2E7D32)
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      debugPrint("❌ SUPABASE TRANSACTION FAILED: $e");

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Submission Error", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(color: Colors.green)),
              )
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Rate Your Experience',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'How was your interaction with ${widget.targetName}?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final int starValue = index + 1;
              return IconButton(
                iconSize: 40,
                icon: Icon(
                  starValue <= _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: starValue <= _selectedRating ? const Color(0xFF4CAF50) : Colors.white30,
                ),
                onPressed: () => setState(() => _selectedRating = starValue),
              );
            }),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _commentController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add additional context or audit comments here (optional)...',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withAlpha(13), // Adjusted cleanly for modern SDK versions
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSubmitting ? null : _submitReview,
            child: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit Evaluation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
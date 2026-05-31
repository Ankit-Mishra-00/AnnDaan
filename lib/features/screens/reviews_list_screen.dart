import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewsListScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const ReviewsListScreen({super.key, required this.userId, required this.userName});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("$userName's Feedback Ledger", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // Fetch reviews where this user is the target (reviewee_id)
        // Also fetch the reviewer's full name from the profiles table using Supabase joins
        future: supabase
            .from('reviews')
            .select('id, rating, comment, created_at, profiles!reviews_reviewer_id_fkey(full_name)')
            .eq('reviewee_id', userId)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error loading reviews: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }

          final reviews = snapshot.data ?? [];

          if (reviews.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_outline, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text("No reviews submitted yet", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                  const Text("Completed rescue cycles will display score logs here.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              final int rating = review['rating'] ?? 5;
              final String comment = review['comment'] ?? 'No text comment provided.';

              // Safely extract the reviewer's name nested from our table join query
              final reviewerData = review['profiles'] as Map<String, dynamic>?;
              final String reviewerName = reviewerData?['full_name'] ?? 'Anonymous Peer';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(reviewerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),

                          // Custom built tiny star rating strip row indicator
                          Row(
                            children: List.generate(5, (starIndex) {
                              return Icon(
                                starIndex < rating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Text(
                        comment,
                        style: const TextStyle(color: Colors.black87, height: 1.4, fontSize: 14),
                      ),
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
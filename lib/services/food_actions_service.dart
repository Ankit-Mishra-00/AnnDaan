import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FoodActionsService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<void> executeClaimTransaction({
    required BuildContext context,
    required String listingId,
    required String deliveryType,
    required String title,
    String? deliveryAddress, // 🌟 Add this optional parameter for custom drop-off coordinates
    VoidCallback? onSuccess,
  }) async {
    final user = _supabase.auth.currentUser;

    // Safety check: ensure user is actively authenticated
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication error: Please log back in."), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      // 1. Update database status with safe parameter payload parsing
      final Map<String, dynamic> updatePayload = {
        'status': 'claimed',
        'receiver_id': user.id,
        'delivery_type': deliveryType,
      };

      // 🌟 Seamlessly inject the custom address if the user provided one
      if (deliveryAddress != null && deliveryAddress.trim().isNotEmpty) {
        updatePayload['delivery_address'] = deliveryAddress.trim();
      } else {
        // Explicitly wipe out any stale or legacy overrides if using profile defaults
        updatePayload['delivery_address'] = null;
      }

      // Explicitly remove or write a structural clear token to field parameters
      updatePayload['volunteer_id'] = null;

      await _supabase
          .from('food_listings')
          .update(updatePayload)
          .eq('id', listingId);

      // Guard check to ensure view layer frame is still mounted
      if (!context.mounted) return;

      // 2. Show the confirmation toast message instantly
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deliveryType == 'self_pickup'
              ? "Claim complete! Secured '$title' for direct self-arranged collection. 🎉"
              : "Claim complete! Requested system volunteer transit assistance for '$title'. 🚚"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      // 3. Trigger screen cleanup navigation rules if provided
      if (onSuccess != null) {
        onSuccess();
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error completing transaction: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

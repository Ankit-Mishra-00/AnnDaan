import 'dart:ui'; // 🌟 Required for the premium BackdropFilter effect
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/food_actions_service.dart';
import '../screens/login_screen.dart';

class FoodDetails extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final String expiryText;
  final bool isUrgent;

  const FoodDetails({
    super.key,
    required this.itemData,
    required this.expiryText,
    required this.isUrgent,
  });

  // The Master Guard Interceptor Engine
  void _processClaimAction(BuildContext context, String listingId, String title) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      _showLoginPromptDialog(context);
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.green)),
      );

      final data = await supabase
          .from('profiles')
          .select('is_verified')
          .eq('id', currentUser.id)
          .single();

      if (!context.mounted) return;
      Navigator.pop(context);

      final bool isVerified = data['is_verified'] ?? false;

      if (!isVerified) {
        _showPendingVerificationDialog(context);
      } else {
        _claimFoodItem(context, listingId, title);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profile verification check failure: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showLoginPromptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Authentication Required", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("You need to create an account or login to lock allocations, finalize delivery details, and process cargo claims."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text("Login / Sign Up", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPendingVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gpp_maybe_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("Verification Pending"),
          ],
        ),
        content: const Text("Your account details are under review by an administrator. You will gain access to claim batches and assign delivery runs the moment your registration is approved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Understood", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _claimFoodItem(BuildContext parentContext, String listingId, String title) async {
    bool isParcelConfirmed = false;
    bool useCustomAddress = false;
    final TextEditingController addressController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Claim '$title'", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: StatefulBuilder(
          builder: (BuildContext dialogFrameContext, StateSetter setDialogState) {
            return SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Please verify your allocation criteria below:",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "I confirm that our organization will reliably receive this parcel upon dispatch.",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      value: isParcelConfirmed,
                      activeColor: Colors.green,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          isParcelConfirmed = value ?? false;
                        });
                      },
                    ),

                    if (isParcelConfirmed) ...[
                      const Divider(height: 24),
                      const Text(
                        "Do you need independent volunteer system support to deliver this order, or can your team handle direct transport collection?",
                        style: TextStyle(fontSize: 13, height: 1.3, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.storefront, color: Colors.white),
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              await FoodActionsService.executeClaimTransaction(
                                context: parentContext,
                                listingId: listingId,
                                deliveryType: 'self_pickup',
                                title: title,
                                deliveryAddress: null, // Self-pickup clears custom delivery rules
                                onSuccess: () {
                                  if (Navigator.canPop(parentContext)) {
                                    Navigator.pop(parentContext);
                                  }
                                },
                              );
                            },
                            label: const Text(
                              "No, Self-Pickup (We will drive)",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // VOLUNTEER TRUCK DELIVERY LOGIC SECTOR
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50.withAlpha(128),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.pin_drop_outlined, size: 18, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Drop-off Destination",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                                    ),
                                    const Spacer(),
                                    Switch(
                                      value: useCustomAddress,
                                      activeThumbColor: Colors.blue.shade700,
                                      onChanged: (val) {
                                        setDialogState(() {
                                          useCustomAddress = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                Text(
                                  useCustomAddress ? "Deliver to a custom address" : "Deliver to default saved organizational profile address",
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                ),
                                if (useCustomAddress) ...[
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: addressController,
                                    maxLines: 2,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: "Enter alternative complete drop-off address...",
                                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                      contentPadding: const EdgeInsets.all(10),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (useCustomAddress && (value == null || value.trim().isEmpty)) {
                                        return "Please provide destination criteria address details.";
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.handshake_outlined, color: Colors.white),
                                    onPressed: () async {
                                      if (formKey.currentState?.validate() ?? false) {
                                        Navigator.pop(dialogContext);

                                        final customDeliveryAddress = useCustomAddress ? addressController.text.trim() : null;

                                        // 🌟 CRASH-FREE ATOMIC TRANSACTION INVOKED DIRECTLY HERE
                                        await FoodActionsService.executeClaimTransaction(
                                          context: parentContext,
                                          listingId: listingId,
                                          deliveryType: 'needs_volunteer',
                                          title: title,
                                          deliveryAddress: customDeliveryAddress, // Passed right here!
                                          onSuccess: () {
                                            if (Navigator.canPop(parentContext)) {
                                              Navigator.pop(parentContext);
                                            }
                                          },
                                        );
                                      }
                                    },
                                    label: const Text(
                                      "Yes, Need Volunteer Support",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String listingId = itemData['id']?.toString() ?? '';
    final String title = itemData['title'] ?? 'Surplus Food Material';
    final String caterer = itemData['caterer_name'] ?? 'Anonymous Donor';
    final String itemsDesc = itemData['items_description'] ?? 'No description provided.';
    final int servings = itemData['servings_count'] ?? 0;
    final double weight = double.tryParse(itemData['food_weight_kg']?.toString() ?? '0') ?? 0.0;
    final double fee = double.tryParse(itemData['delivery_fee']?.toString() ?? '0') ?? 0.0;
    final String address = itemData['pickup_address'] ?? 'Address detailed on claim receipt';
    final bool providesDelivery = itemData['provides_delivery'] ?? false;

    final String rawImageUrl = itemData['image_url']?.toString() ?? '';
    final List<String> imageUrls = rawImageUrl.isNotEmpty ? rawImageUrl.split(',') : [];

    final PageController sliderController = PageController();
    final ValueNotifier<int> activeImageIndex = ValueNotifier<int>(0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Food Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 260,
              width: double.infinity,
              color: Colors.black,
              child: imageUrls.isEmpty
                  ? Center(child: Icon(Icons.restaurant, size: 80, color: Colors.grey.shade600))
                  : Stack(
                children: [
                  PageView.builder(
                    controller: sliderController,
                    itemCount: imageUrls.length,
                    onPageChanged: (index) => activeImageIndex.value = index,
                    itemBuilder: (context, index) {
                      final imageUrl = imageUrls[index];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                          ),
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(color: Colors.black.withAlpha(90)),
                          ),
                          Center(
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (imageUrls.length > 1)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: ValueListenableBuilder<int>(
                        valueListenable: activeImageIndex,
                        builder: (context, currentIdx, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24, width: 0.5),
                            ),
                            child: Text(
                              "${currentIdx + 1} / ${imageUrls.length}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Posted by $caterer", style: const TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isUrgent ? Colors.red.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          expiryText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isUrgent ? Colors.red.shade800 : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  const Text("Items Included", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(itemsDesc, style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.4)),
                  const Divider(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMetricIcon(Icons.people_alt_outlined, "$servings+", "Servings"),
                      _buildMetricIcon(Icons.scale_outlined, weight > 0 ? "${weight}kg" : "N/A", "Est. Weight"),
                      _buildMetricIcon(
                        providesDelivery ? Icons.local_shipping_outlined : Icons.directions_walk_outlined,
                        providesDelivery ? "Provided" : "Self-Pickup",
                        "Logistics",
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  const Text("Pickup Location Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Pricing", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            fee > 0 ? "₹${fee.toStringAsFixed(0)}" : "Free Asset",
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 50,
                        width: MediaQuery.of(context).size.width * 0.55,
                        child: ElevatedButton(
                          onPressed: () => _processClaimAction(context, listingId, title),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isUrgent ? Colors.red.shade600 : Colors.green.shade600,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Claim Food Material",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricIcon(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.green.shade600),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
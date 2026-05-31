import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class DonorUploadScreen extends StatefulWidget {
  const DonorUploadScreen({super.key});

  @override
  State<DonorUploadScreen> createState() => _DonorUploadScreenState();
}

class _DonorUploadScreenState extends State<DonorUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  final _titleCtrl = TextEditingController();
  final _catererCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController();

  // Custom operational fee breakdowns
  final _baseDeliveryFeeCtrl = TextEditingController(text: '0');
  final _packingFeeCtrl = TextEditingController(text: '0');
  final _laborFeeCtrl = TextEditingController(text: '0');

  final _weightCtrl = TextEditingController(text: '0');
  final _addressCtrl = TextEditingController();

  String _category = 'Veg';
  bool _providesDelivery = false;
  bool _isLoading = false;

  List<File> _imageFiles = [];
  int _bestBeforeHours = 4;
  final List<int> _hoursOptions = List.generate(24, (index) => index + 1);

  bool _useSavedAddress = false;
  String _profileSavedAddress = '';

  @override
  void initState() {
    super.initState();
    _fetchUserSavedAddress();
  }

  // 🌟 UPDATED: Fetches profile location details using 'address_text' column name
  Future<void> _fetchUserSavedAddress() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('profiles')
          .select('address_text')
          .eq('id', user.id)
          .single();

      if (data['address_text'] != null) {
        setState(() {
          _profileSavedAddress = data['address_text'] as String;
        });
      }
    } catch (e) {
      debugPrint("Could not fetch saved profile address: $e");
    }
  }

  Future<void> _showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text("Take Photo with Camera"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("Select Multiple from Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickMultiImages();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile != null) {
        setState(() => _imageFiles.add(File(pickedFile.path)));
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _pickMultiImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 85);
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _imageFiles.addAll(pickedFiles.map((file) => File(file.path)));
        });
      }
    } catch (e) {
      debugPrint("Error picking multiple images: $e");
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one food photo"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("User session not found.");

      List<String> uploadedImageUrls = [];

      // 1. Upload all local assets to storage buckets
      for (var file in _imageFiles) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
        await _supabase.storage.from('food_images').upload(fileName, file);
        final url = _supabase.storage.from('food_images').getPublicUrl(fileName);
        uploadedImageUrls.add(url);
      }

      final consolidatedImageUrlsString = uploadedImageUrls.join(',');

      // Fees Consolidation
      final double baseDelivery = double.tryParse(_baseDeliveryFeeCtrl.text) ?? 0.0;
      final double packingCharge = double.tryParse(_packingFeeCtrl.text) ?? 0.0;
      final double laborCharge = double.tryParse(_laborFeeCtrl.text) ?? 0.0;
      final double totalCombinedDeliveryFee = baseDelivery + packingCharge + laborCharge;

      // 2. Insert payload data directly into public.food_listings
      await _supabase.from('food_listings').insert({
        'donor_id': user.id,
        'title': _titleCtrl.text.trim(),
        'caterer_name': _catererCtrl.text.trim(),
        'items_description': _descCtrl.text.trim(),
        'servings_count': int.tryParse(_servingsCtrl.text) ?? 0,
        'delivery_fee': totalCombinedDeliveryFee,
        'category': _category,
        'status': 'available',
        'image_url': consolidatedImageUrlsString,
        'provides_delivery': _providesDelivery,
        'best_before_hours': _bestBeforeHours,
        'food_weight_kg': double.tryParse(_weightCtrl.text) ?? 0.0,
        'pickup_address': _addressCtrl.text.trim(),

        // 🌟 UPDATED: If they are using a saved profile address, custom address is FALSE.
        // If they turned off the toggle to write their own, custom address is TRUE.
        'is_custom_address': !_useSavedAddress,

        'delivery_type': _providesDelivery ? 'donor_delivery' : 'needs_volunteer',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Food listing published successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submission Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.teal;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Post New Food Listing", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildSectionTitle("Food Photos (${_imageFiles.length})"),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _imageFiles.length + 1,
                itemBuilder: (context, index) {
                  if (index == _imageFiles.length) {
                    return GestureDetector(
                      onTap: _showImageSourceOptions,
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.withOpacity(0.2), style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: primaryColor, size: 28),
                            const SizedBox(height: 4),
                            Text("Add Photo", style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      Container(
                        width: 120,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(image: FileImage(_imageFiles[index]), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _imageFiles.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      )
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            _buildSectionTitle("Food Specifications"),
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: "Dish Title", prefixIcon: Icon(Icons.restaurant_menu), border: OutlineInputBorder()),
                      validator: (v) => v!.trim().isEmpty ? "Title is required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _catererCtrl,
                      decoration: const InputDecoration(labelText: "Caterer / Cook Name", prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                      validator: (v) => v!.trim().isEmpty ? "Provider identity is required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: "Description & Ingredients", border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),

            _buildSectionTitle("Logistics & Metrics"),
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(labelText: "Food Category", prefixIcon: Icon(Icons.category_outlined), border: OutlineInputBorder()),
                      items: ['Veg', 'Non-Veg', 'Large Qty'].map((e) {
                        return DropdownMenuItem(
                          value: e,
                          child: Row(
                            children: [
                              Icon(Icons.fiber_manual_record, color: e == 'Veg' ? Colors.green : (e == 'Non-Veg' ? Colors.red : Colors.orange), size: 14),
                              const SizedBox(width: 8),
                              Text(e),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _category = val!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _servingsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Servings", border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _weightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Weight (kg)", border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _bestBeforeHours,
                      decoration: const InputDecoration(labelText: "Best Before (Consume Within)", prefixIcon: Icon(Icons.timer_outlined), border: OutlineInputBorder()),
                      items: _hoursOptions.map((int hour) {
                        return DropdownMenuItem<int>(
                          value: hour,
                          child: Text(hour == 24 ? '24 Hours (1 Day)' : '$hour ${hour == 1 ? "Hour" : "Hours"}'),
                        );
                      }).toList(),
                      onChanged: (int? nv) => setState(() => _bestBeforeHours = nv!),
                    ),
                  ],
                ),
              ),
            ),

            _buildSectionTitle("Operational Charges (₹)"),
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _baseDeliveryFeeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Base Delivery Fee", prefixIcon: Icon(Icons.delivery_dining_outlined), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _packingFeeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Packing Charge", prefixIcon: Icon(Icons.inventory_2_outlined), border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _laborFeeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Labor & Handling", prefixIcon: Icon(Icons.handyman_outlined), border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            _buildSectionTitle("Fulfillment & Location"),
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: primaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Use my saved profile address"),
                      subtitle: _profileSavedAddress.isNotEmpty
                          ? Text(_profileSavedAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))
                          : const Text("No profile address found. Enter below.", style: TextStyle(fontSize: 12, color: Colors.orange)),
                      value: _useSavedAddress,
                      onChanged: _profileSavedAddress.isNotEmpty
                          ? (bool val) {
                        setState(() {
                          _useSavedAddress = val;
                          _addressCtrl.text = val ? _profileSavedAddress : '';
                        });
                      }
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressCtrl,
                      maxLines: 2,
                      enabled: !_useSavedAddress,
                      decoration: const InputDecoration(labelText: "Pickup Address", prefixIcon: Icon(Icons.location_on_outlined), border: OutlineInputBorder()),
                      validator: (v) => v!.trim().isEmpty ? "Pickup location is required" : null,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      activeColor: primaryColor,
                      contentPadding: EdgeInsets.zero,
                      title: const Text("I can deliver this food myself"),
                      subtitle: const Text("Turning this off requests a community volunteer courier"),
                      value: _providesDelivery,
                      onChanged: (v) => setState(() => _providesDelivery = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                    : const Text("Publish Donation Listing", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class DonorUploadScreen extends StatefulWidget {
  const DonorUploadScreen({super.key});

  @override
  State<DonorUploadScreen> createState() => _DonorUploadScreenState();
}

class _DonorUploadScreenState extends State<DonorUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _titleCtrl = TextEditingController();
  final _catererCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController();
  final _feeCtrl = TextEditingController(text: '0');
  final _weightCtrl = TextEditingController(text: '0');
  final _hoursCtrl = TextEditingController(text: '4');
  final _addressCtrl = TextEditingController();

  String _category = 'Veg';
  bool _providesDelivery = false;
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    // FIXED: Use .platform.pickFiles
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _imageFile = File(result.files.single.path!));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an image")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(_imageFile!.path)}';

      // 1. Upload Image
      // Check this line in your _submit() method:
      await _supabase.storage.from('food_images').upload(fileName, _imageFile!);
      final imageUrl = _supabase.storage.from('food_images').getPublicUrl(fileName);

      // 2. Insert Record
      await _supabase.from('food_listings').insert({
        'donor_id': userId,
        'title': _titleCtrl.text,
        'caterer_name': _catererCtrl.text,
        'items_description': _descCtrl.text,
        'servings_count': int.tryParse(_servingsCtrl.text) ?? 0,
        'delivery_fee': double.tryParse(_feeCtrl.text) ?? 0.0,
        'category': _category,
        'status': 'available',
        'image_url': imageUrl,
        'provides_delivery': _providesDelivery,
        'best_before_hours': int.tryParse(_hoursCtrl.text) ?? 4,
        'food_weight_kg': double.tryParse(_weightCtrl.text) ?? 0.0,
        'pickup_address': _addressCtrl.text,
        'is_custom_address': false,
        'delivery_type': _providesDelivery ? 'donor_delivery' : 'needs_volunteer',
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post New Listing")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                color: Colors.grey[200],
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40), Text("Add Image")]),
              ),
            ),
            TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: "Dish Title"), validator: (v) => v!.isEmpty ? "Required" : null),
            TextFormField(controller: _catererCtrl, decoration: const InputDecoration(labelText: "Caterer Name"), validator: (v) => v!.isEmpty ? "Required" : null),
            TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: "Ingredients Description")),
            TextFormField(controller: _servingsCtrl, decoration: const InputDecoration(labelText: "Servings Count"), keyboardType: TextInputType.number),
            DropdownButtonFormField<String>(
              value: _category,
              items: ['Veg', 'Non-Veg', 'Large Qty'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _category = val!),
            ),
            SwitchListTile(title: const Text("Provide Delivery?"), value: _providesDelivery, onChanged: (v) => setState(() => _providesDelivery = v)),
            TextFormField(controller: _feeCtrl, decoration: const InputDecoration(labelText: "Fee (₹)"), keyboardType: TextInputType.number),
            TextFormField(controller: _weightCtrl, decoration: const InputDecoration(labelText: "Weight (kg)"), keyboardType: TextInputType.number),
            TextFormField(controller: _hoursCtrl, decoration: const InputDecoration(labelText: "Best Before (Hours)"), keyboardType: TextInputType.number),
            TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: "Pickup Address")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading ? const CircularProgressIndicator() : const Text("Publish Listing"),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class VerificationUploadScreen extends StatefulWidget {
  const VerificationUploadScreen({super.key});

  @override
  State<VerificationUploadScreen> createState() => _VerificationUploadScreenState();
}

class _VerificationUploadScreenState extends State<VerificationUploadScreen> {
  final _formKey = GlobalKey<FormState>();

  // 🗲 CONTROLLERS MATCHING YOUR SCHEMA COLUMNS
  final _orgNameController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _governmentIdController = TextEditingController();
  final _physicalAddressController = TextEditingController();

  String? _licenseDocPath;
  String? _govIdDocPath;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _orgNameController.dispose();
    _licenseNumberController.dispose();
    _governmentIdController.dispose();
    _physicalAddressController.dispose();
    super.dispose();
  }

  // 🗲 HANDLES PLATFORM-SAFE PICKING AND STORAGE STAGING
  Future<void> _pickDocument(String type) async {
    try {
      // 1. Trigger native system file explorer using cross-platform configuration API
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png'],
      );

      if (result == null || result.files.single.path == null) return;

      File file = File(result.files.single.path!);

      // 2. Client-side File Size Validation Check (5MB Limit)
      int fileSizeInBytes = await file.length();
      if (fileSizeInBytes > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File size exceeds the 5MB limit."), backgroundColor: Colors.redAccent),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 3. Generate a clean, unique file name configuration
      String fileExtension = p.extension(file.path);
      String storagePath = '$userId/${type}_verification$fileExtension';

      // 4. Upload payload directly into your private Supabase storage bucket
      await supabase.storage.from('verification-docs').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(upsert: true), // Overwrites if they re-upload
      );

      // 5. Save the path reference to update the UI display state securely
      setState(() {
        if (type == 'license') {
          _licenseDocPath = p.basename(file.path);
        } else {
          _govIdDocPath = p.basename(file.path);
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${p.basename(file.path)} uploaded successfully!")),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload error encountered: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitVerificationData() async {
    if (!_formKey.currentState!.validate()) return;

    if (_licenseDocPath == null || _govIdDocPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please upload both required verification documents."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      // 💾 UPDATES THE EXACT SCHEMA COLUMNS CURRENTLY PRESENT IN YOUR DB
      await supabase.from('profiles').update({
        'organization_name': _orgNameController.text.trim(),
        'license_number': _licenseNumberController.text.trim(),
        'government_id': _governmentIdController.text.trim(),
        'physical_address': _physicalAddressController.text.trim(),
        'is_verified': false, // Keeps user locked under review until admin confirmation
      }).eq('id', userId);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text("Documents Lodged"),
            ],
          ),
          content: const Text("Your profile verification parameters have been saved. Administrators are processing your review request. This layout unlocks automatically upon validation."),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context); // Fallback to details view cleanly
              },
              child: const Text("Return to Feed", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submission Failure: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Trust & Safety Check", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.gpp_good_outlined, color: Colors.green.shade700, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "To ensure absolute food security and regulatory clarity across the local logistics corridor, please fill out your verification profile.",
                          style: TextStyle(fontSize: 12, color: Colors.green.shade800, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text("Organizational Metadata", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // 🏢 Field 1: Organization Name
                TextFormField(
                  controller: _orgNameController,
                  validator: (val) => val == null || val.trim().isEmpty ? "Enter registered organization name" : null,
                  decoration: InputDecoration(
                    labelText: "Organization Name",
                    prefixIcon: const Icon(Icons.business_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // 📜 Field 2: License Number
                TextFormField(
                  controller: _licenseNumberController,
                  validator: (val) => val == null || val.trim().isEmpty ? "Enter NGO Certificate/License identifier" : null,
                  decoration: InputDecoration(
                    labelText: "License / Registration Number",
                    hintText: "e.g., Trust Deed / Society Incorporation ID",
                    prefixIcon: const Icon(Icons.gavel_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // 🪪 Field 3: Government ID String Track
                TextFormField(
                  controller: _governmentIdController,
                  validator: (val) => val == null || val.trim().isEmpty ? "Enter a valid Government verification ID" : null,
                  decoration: InputDecoration(
                    labelText: "Representative Government ID Number",
                    hintText: "e.g., Corporate ID / Tax ID / Unique Identity copy",
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // 📍 Field 4: Physical Address
                TextFormField(
                  controller: _physicalAddressController,
                  maxLines: 2,
                  validator: (val) => val == null || val.trim().isEmpty ? "Enter headquarters physical location address" : null,
                  decoration: InputDecoration(
                    labelText: "Physical Operating Address",
                    prefixIcon: const Icon(Icons.map_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 28),

                const Text("Upload Verifiable Credentials", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Document Box A: License Document Asset
                _buildFileSelectorCard(
                  title: "Copy of Corporate License / Registration",
                  isAttached: _licenseDocPath != null,
                  fileName: _licenseDocPath,
                  onTap: () => _isSubmitting ? null : _pickDocument('license'),
                ),
                const SizedBox(height: 12),

                // Document Box B: Representative Identity Document Asset
                _buildFileSelectorCard(
                  title: "Copy of Representative Government ID",
                  isAttached: _govIdDocPath != null,
                  fileName: _govIdDocPath,
                  onTap: () => _isSubmitting ? null : _pickDocument('gov_id'),
                ),
                const SizedBox(height: 40),

                // Submission Action Execution Control Panel
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _submitVerificationData,
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                        : const Text("Submit Verification Profile", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileSelectorCard({
    required String title,
    required bool isAttached,
    required String? fileName,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isAttached ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isAttached ? Colors.green.shade300 : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              isAttached ? Icons.check_circle_rounded : Icons.file_upload_outlined,
              color: isAttached ? Colors.green.shade700 : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (isAttached) ...[
                    const SizedBox(height: 2),
                    Text("📎 $fileName", style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.bold)),
                  ]
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isAttached ? Colors.green.shade400 : Colors.grey.shade400)
          ],
        ),
      ),
    );
  }
}
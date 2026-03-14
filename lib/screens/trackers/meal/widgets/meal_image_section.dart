import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../config/app_theme.dart';

class MealImageSection extends StatelessWidget {
  final Uint8List? imageBytes;
  final bool isAnalyzing;
  final Future<void> Function(Uint8List bytes, String name) onImagePicked;

  const MealImageSection({
    super.key,
    required this.imageBytes,
    required this.isAnalyzing,
    required this.onImagePicked,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: source, maxWidth: 1024, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await onImagePicked(bytes, file.name);
  }

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showSourceSheet(context),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              image: imageBytes != null
                  ? DecorationImage(
                      image: MemoryImage(imageBytes!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageBytes == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt,
                          size: 48, color: AppTheme.mutedForeground),
                      SizedBox(height: 8),
                      Text('Foto aufnehmen',
                          style: TextStyle(color: AppTheme.mutedForeground)),
                    ],
                  )
                : null,
          ),
        ),
        if (isAnalyzing)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(height: 8),
                Text('KI analysiert...',
                    style: TextStyle(color: AppTheme.mutedForeground)),
              ],
            ),
          ),
      ],
    );
  }
}

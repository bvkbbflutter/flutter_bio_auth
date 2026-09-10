import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:image_picker/image_picker.dart';

class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _firstImageBytes;
  Uint8List? _secondImageBytes;
  bool _comparing = false;
  String? _error;
  FaceMatchResult? _result;

  Future<void> _pickImage({required bool first}) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo (Camera)'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final XFile? file = await _picker.pickImage(source: source);
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    setState(() {
      if (first) {
        _firstImageBytes = bytes;
      } else {
        _secondImageBytes = bytes;
      }
      _result = null;
      _error = null;
    });
  }

  Future<void> _compare() async {
    final Uint8List? a = _firstImageBytes;
    final Uint8List? b = _secondImageBytes;
    if (a == null || b == null) {
      setState(() => _error = 'Select both images first.');
      return;
    }
    setState(() {
      _comparing = true;
      _error = null;
      _result = null;
    });
    try {
      final FaceMatchResult result =
          await FaceBiometric.compare(firstImage: a, secondImage: b);
      setState(() => _result = result);
    } on BiometricError catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _comparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare Faces')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                    child: _ImageSlot(
                        bytes: _firstImageBytes,
                        label: 'Image 1',
                        onTap: () => _pickImage(first: true))),
                const SizedBox(width: 12),
                Expanded(
                    child: _ImageSlot(
                        bytes: _secondImageBytes,
                        label: 'Image 2',
                        onTap: () => _pickImage(first: false))),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _comparing ? null : _compare,
              child: Text(_comparing ? 'Comparing…' : 'Compare'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_result != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _result!.isMatch
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            _result!.isMatch ? Icons.verified : Icons.cancel,
                            color: _result!.isMatch
                                ? Colors.green
                                : Theme.of(context).colorScheme.error,
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _result!.isMatch
                                ? 'FACES MATCH'
                                : 'FACES DO NOT MATCH',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _result!.isMatch
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value:
                              ((_result!.similarity + 1) / 2).clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _result!.isMatch ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                              'Cosine Similarity: ${(_result!.similarity * 100).toStringAsFixed(1)}%',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                              'Threshold: ${(_result!.threshold * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.outline)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot(
      {required this.bytes, required this.label, required this.onTap});

  final Uint8List? bytes;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: bytes == null
              ? Center(child: Text('Tap to select $label'))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes!, fit: BoxFit.cover)),
        ),
      ),
    );
  }
}

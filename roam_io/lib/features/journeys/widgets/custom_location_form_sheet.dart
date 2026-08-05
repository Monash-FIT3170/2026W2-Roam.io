import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/storage_service.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../domain/journey_location.dart';

/// Create/edit form for journey-created custom locations.
class CustomLocationFormSheet extends StatefulWidget {
  const CustomLocationFormSheet({
    super.key,
    required this.location,
    required this.userId,
  });

  final JourneyLocation location;
  final String userId;

  static Future<JourneyLocation?> show({
    required BuildContext context,
    required JourneyLocation location,
    required String userId,
  }) {
    return showModalBottomSheet<JourneyLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CustomLocationFormSheet(location: location, userId: userId),
    );
  }

  @override
  State<CustomLocationFormSheet> createState() =>
      _CustomLocationFormSheetState();
}

class _CustomLocationFormSheetState extends State<CustomLocationFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final _picker = ImagePicker();
  late final List<_LocationMedia> _media;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.location.name);
    _descriptionController = TextEditingController(
      text: widget.location.description ?? '',
    );
    _media = widget.location.mediaUrls.map(_LocationMedia.fromUrl).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addFromGallery() async {
    final files = await _picker.pickMultipleMedia(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (files.isNotEmpty && mounted) {
      setState(() => _media.addAll(files.map(_LocationMedia.fromFile)));
    }
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (file != null && mounted) {
      setState(() => _media.add(_LocationMedia.fromFile(file)));
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a location name.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final storage = StorageService();
      final key =
          '${widget.location.latLng.latitude}_${widget.location.latLng.longitude}';
      final urls = <String>[];
      for (final item in _media) {
        if (item.url != null) {
          urls.add(item.url!);
        } else if (item.file != null) {
          urls.add(
            await storage.uploadCustomLocationMedia(
              uid: widget.userId,
              locationKey: key,
              bytes: await File(item.file!.path).readAsBytes(),
              filename: item.file!.name,
            ),
          );
        }
      }

      final description = _descriptionController.text.trim();
      final updated = JourneyLocation(
        latLng: widget.location.latLng,
        placeId: widget.location.placeId,
        displayName: widget.location.displayName,
        customName: name == widget.location.displayName ? null : name,
        description: description.isEmpty ? null : description,
        mediaUrls: urls,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this location. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      key: const ValueKey('custom_location_keyboard_padding'),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        decoration: BoxDecoration(
          color: AppSurfaces.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Custom location',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Location name',
                    prefixIcon: Icon(
                      Icons.circle,
                      color: Colors.black,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Add notes about this location',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                Text('Media', style: Theme.of(context).textTheme.titleSmall),
                if (_media.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 88,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _media.length,
                      itemBuilder: (_, index) {
                        final item = _media[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 88,
                                  height: 88,
                                  child: item.file != null
                                      ? Image.file(
                                          File(item.file!.path),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.videocam),
                                        )
                                      : Image.network(
                                          item.url!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.videocam),
                                        ),
                                ),
                              ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: InkWell(
                                  onTap: _saving
                                      ? null
                                      : () => setState(
                                          () => _media.removeAt(index),
                                        ),
                                  child: const CircleAvatar(
                                    radius: 11,
                                    backgroundColor: Colors.black54,
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _addFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _takePhoto,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Camera'),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.clay)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save location'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationMedia {
  const _LocationMedia({this.url, this.file});

  factory _LocationMedia.fromUrl(String url) => _LocationMedia(url: url);
  factory _LocationMedia.fromFile(XFile file) => _LocationMedia(file: file);

  final String? url;
  final XFile? file;
}

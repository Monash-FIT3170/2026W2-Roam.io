import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/storage_service.dart';
import '../../../theme/app_colours.dart';
import 'place_of_interest.dart';
import 'visit.dart';
import 'visit_service.dart';

typedef CreateVisitCallback =
    Future<void> Function({
      String? customName,
      String? description,
      List<String>? mediaUrls,
    });

/// Result of the visit form submission.
enum VisitFormResult {
  /// Successfully saved the visit.
  success,

  /// User cancelled the form.
  cancelled,

  /// An error occurred during save.
  error,
}

/// Bottom sheet for creating or editing a visit.
/// Allows user to set custom name, description, and add media.
class VisitFormSheet extends StatefulWidget {
  const VisitFormSheet({
    super.key,
    required this.place,
    required this.userId,
    this.existingVisit,
    this.visitService,
    this.storageService,
    this.onCreateVisit,
  });

  final PlaceOfInterest place;
  final String userId;

  /// If provided, the form is in edit mode for an existing visit.
  final Visit? existingVisit;

  /// Optional override for tests or alternate persistence layers.
  final VisitService? visitService;

  /// Optional override for tests or alternate upload backends.
  final StorageService? storageService;

  /// Optional create handler used when the caller needs to own visit persistence.
  final CreateVisitCallback? onCreateVisit;

  /// Shows the visit form sheet as a modal bottom sheet.
  /// Returns the result of the form submission.
  static Future<VisitFormResult?> show({
    required BuildContext context,
    required PlaceOfInterest place,
    required String userId,
    Visit? existingVisit,
    VisitService? visitService,
    StorageService? storageService,
    CreateVisitCallback? onCreateVisit,
  }) {
    return showModalBottomSheet<VisitFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VisitFormSheet(
        place: place,
        userId: userId,
        existingVisit: existingVisit,
        visitService: visitService,
        storageService: storageService,
        onCreateVisit: onCreateVisit,
      ),
    );
  }

  @override
  State<VisitFormSheet> createState() => _VisitFormSheetState();
}

class _VisitFormSheetState extends State<VisitFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();

  final List<_MediaItem> _mediaItems = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditMode => widget.existingVisit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _nameController.text = widget.existingVisit!.customName ?? '';
      _descriptionController.text = widget.existingVisit!.description ?? '';
      // Load existing media URLs
      for (final url in widget.existingVisit!.mediaUrls) {
        _mediaItems.add(_MediaItem.fromUrl(url));
      }
    } else {
      _nameController.text = widget.place.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _mediaItems.add(_MediaItem.fromFile(pickedFile));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not access photo library. Please check permissions.',
          ),
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (pickedFile != null) {
        setState(() {
          _mediaItems.add(_MediaItem.fromFile(pickedFile, isVideo: true));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not access video library. Please check permissions.',
          ),
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _mediaItems.add(_MediaItem.fromFile(pickedFile));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not access camera. Please check permissions.'),
        ),
      );
    }
  }

  Future<void> _takeVideo() async {
    try {
      final pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );
      if (pickedFile != null) {
        setState(() {
          _mediaItems.add(_MediaItem.fromFile(pickedFile, isVideo: true));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not access camera. Please check permissions.'),
        ),
      );
    }
  }

  Future<void> _chooseMedia() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'photo') {
      await _pickImage();
    } else if (choice == 'video') {
      await _pickVideo();
    }
  }

  Future<void> _captureMedia() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'photo') {
      await _takePhoto();
    } else if (choice == 'video') {
      await _takeVideo();
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaItems.removeAt(index);
    });
  }

  Future<void> _saveVisit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint(
        '[VisitFormSheet] Starting save visit for place: ${widget.place.id}',
      );
      debugPrint('[VisitFormSheet] User ID: ${widget.userId}');

      final storageService = widget.storageService ?? StorageService();
      final visitService = widget.visitService ?? VisitService();

      // Upload new media files
      final mediaUrls = <String>[];
      debugPrint(
        '[VisitFormSheet] Processing ${_mediaItems.length} media items',
      );

      for (int i = 0; i < _mediaItems.length; i++) {
        final item = _mediaItems[i];
        if (item.url != null) {
          // Existing media, keep the URL
          debugPrint('[VisitFormSheet] Media $i: keeping existing URL');
          mediaUrls.add(item.url!);
        } else if (item.file != null) {
          // New media, upload it
          debugPrint(
            '[VisitFormSheet] Media $i: uploading file ${item.file!.name}',
          );
          try {
            final bytes = await item.file!.readAsBytes();
            debugPrint('[VisitFormSheet] Media $i: read ${bytes.length} bytes');
            final url = await storageService.uploadVisitMedia(
              uid: widget.userId,
              placeId: widget.place.id,
              bytes: bytes,
              filename: item.file!.name,
            );
            debugPrint(
              '[VisitFormSheet] Media $i: uploaded successfully, URL: $url',
            );
            mediaUrls.add(url);
          } catch (uploadError, uploadStack) {
            debugPrint(
              '[VisitFormSheet] Media $i: upload failed: $uploadError',
            );
            debugPrint('[VisitFormSheet] Stack trace: $uploadStack');
            rethrow;
          }
        }
      }

      // Get custom name (null if same as place name)
      final customName = _nameController.text.trim();
      final finalCustomName = customName == widget.place.name
          ? null
          : customName;
      debugPrint('[VisitFormSheet] Custom name: $finalCustomName');

      // Get description (null if empty)
      final description = _descriptionController.text.trim();
      final finalDescription = description.isEmpty ? null : description;
      debugPrint(
        '[VisitFormSheet] Description: ${finalDescription?.substring(0, finalDescription.length.clamp(0, 50))}...',
      );

      if (_isEditMode) {
        // Update existing visit
        debugPrint('[VisitFormSheet] Updating existing visit');
        await visitService.updateVisit(
          userId: widget.userId,
          placeId: widget.place.id,
          customName: finalCustomName,
          description: finalDescription,
          mediaUrls: mediaUrls,
        );
      } else {
        // Create new visit
        debugPrint('[VisitFormSheet] Creating new visit');
        if (widget.onCreateVisit != null) {
          await widget.onCreateVisit!(
            customName: finalCustomName,
            description: finalDescription,
            mediaUrls: mediaUrls,
          );
        } else {
          await visitService.markVisited(
            userId: widget.userId,
            place: widget.place,
            customName: finalCustomName,
            description: finalDescription,
            mediaUrls: mediaUrls,
          );
        }
      }

      debugPrint('[VisitFormSheet] Visit saved successfully!');
      if (!mounted) return;
      Navigator.of(context).pop(VisitFormResult.success);
    } catch (e, stackTrace) {
      debugPrint('[VisitFormSheet] ERROR: $e');
      debugPrint('[VisitFormSheet] Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save visit. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + bottomInset,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Text(
                    _isEditMode ? 'Edit Visit' : 'Log Your Visit',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.place.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Custom name field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'Give this place a custom name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description field
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Describe your visit...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 16),

                  // Media section
                  Text('Photos & Videos', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),

                  // Media grid
                  if (_mediaItems.isNotEmpty) ...[
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _mediaItems.length,
                        itemBuilder: (context, index) {
                          return _MediaThumbnail(
                            item: _mediaItems[index],
                            onRemove: () => _removeMedia(index),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Add media buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _chooseMedia,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _captureMedia,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.clay.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 20,
                            color: AppColors.clay,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.clay,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(
                                  context,
                                ).pop(VisitFormResult.cancelled),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveVisit,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            _isLoading
                                ? 'Saving...'
                                : (_isEditMode ? 'Save Changes' : 'Log Visit'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sage,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Represents a media item (either from a file or an existing URL).
class _MediaItem {
  final XFile? file;
  final String? url;
  final bool isVideo;

  _MediaItem.fromFile(this.file, {this.isVideo = false}) : url = null;
  _MediaItem.fromUrl(this.url)
    : file = null,
      isVideo = url!.contains('.mp4') || url.contains('.mov');
}

/// Thumbnail widget for displaying a media item with remove button.
class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({required this.item, required this.onRemove});

  final _MediaItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 100,
              height: 100,
              color: Colors.grey[300],
              child: _buildThumbnail(),
            ),
          ),

          // Video indicator
          if (item.isVideo)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.videocam,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    if (item.file != null) {
      // Local file
      if (item.isVideo) {
        return const Center(
          child: Icon(Icons.videocam, size: 40, color: Colors.grey),
        );
      }
      return Image.file(
        File(item.file!.path),
        fit: BoxFit.cover,
        width: 100,
        height: 100,
      );
    } else if (item.url != null) {
      // Network URL
      if (item.isVideo) {
        return const Center(
          child: Icon(Icons.videocam, size: 40, color: Colors.grey),
        );
      }
      return Image.network(
        item.url!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        errorBuilder: (_, _, _) =>
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    }
    return const Center(child: Icon(Icons.image, color: Colors.grey));
  }
}

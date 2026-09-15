import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../domain/hazard_category.dart';
import '../domain/hazard_submission_exception.dart';
import 'hazard_category_icon.dart';

class HazardSelectedPhoto {
  const HazardSelectedPhoto({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

typedef HazardPhotoPicker = Future<XFile?> Function(ImageSource source);
typedef SubmitHazardReport =
    Future<void> Function({
      required HazardCategory category,
      String? description,
      HazardSelectedPhoto? photo,
    });

class HazardReportSheet extends StatefulWidget {
  const HazardReportSheet({
    super.key,
    required this.category,
    required this.onSubmit,
    this.photoPicker,
  });

  final HazardCategory category;
  final SubmitHazardReport onSubmit;
  final HazardPhotoPicker? photoPicker;

  static Future<bool?> show({
    required BuildContext context,
    required HazardCategory category,
    required SubmitHazardReport onSubmit,
    HazardPhotoPicker? photoPicker,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HazardReportSheet(
        category: category,
        onSubmit: onSubmit,
        photoPicker: photoPicker,
      ),
    );
  }

  @override
  State<HazardReportSheet> createState() => _HazardReportSheetState();
}

class _HazardReportSheetState extends State<HazardReportSheet> {
  final _descriptionController = TextEditingController();
  HazardSelectedPhoto? _photo;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker =
          widget.photoPicker ??
          (source) => ImagePicker().pickImage(
            source: source,
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
          );
      final file = await picker(source);
      if (file == null) return;
      final photo = HazardSelectedPhoto(
        bytes: await file.readAsBytes(),
        filename: file.name,
      );
      if (mounted) setState(() => _photo = photo);
    } catch (error, stackTrace) {
      debugPrint('[HazardReportSheet] Photo selection failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(
          () => _error = 'Could not access that photo. Please try again.',
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final description = _descriptionController.text.trim();
      await widget.onSubmit(
        category: widget.category,
        description: description.isEmpty ? null : description,
        photo: _photo,
      );
      if (mounted) Navigator.pop(context, true);
    } on HazardSubmissionException catch (error, stackTrace) {
      debugPrint('[HazardReportSheet] Submission failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.userMessage;
      });
    } catch (error, stackTrace) {
      debugPrint('[HazardReportSheet] Unexpected submission failure: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not report this hazard. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: keyboard),
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
                      color: AppSurfaces.textSubtle(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Hazard details',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppSurfaces.innerCard(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      HazardCategoryIcon(
                        category: widget.category,
                        color: AppColors.sage,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.category.displayLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('hazard_description'),
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 280,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Add a short note for other travellers',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Photo (optional)', style: theme.textTheme.titleSmall),
                if (_photo != null) ...[
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _photo!.bytes,
                          key: const ValueKey('hazard_photo_preview'),
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: IconButton.filled(
                          key: const ValueKey('remove_hazard_photo'),
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _photo = null),
                          icon: const Icon(Icons.close),
                          tooltip: 'Remove photo',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting
                            ? null
                            : () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          color: AppColors.sage,
                        ),
                        label: Text(_photo == null ? 'Gallery' : 'Replace'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting
                            ? null
                            : () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.sage,
                        ),
                        label: const Text('Camera'),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('submit_hazard'),
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Report hazard'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

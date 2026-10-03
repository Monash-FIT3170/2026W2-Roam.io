import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../domain/hazard_report.dart';
import 'hazard_category_icon.dart';

class HazardDetailsSheet extends StatefulWidget {
  const HazardDetailsSheet({
    super.key,
    required this.report,
    required this.onConfirm,
  });

  final HazardReport report;
  final Future<void> Function() onConfirm;

  static Future<void> show({
    required BuildContext context,
    required HazardReport report,
    required Future<void> Function() onConfirm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HazardDetailsSheet(report: report, onConfirm: onConfirm),
    );
  }

  @override
  State<HazardDetailsSheet> createState() => _HazardDetailsSheetState();
}

class _HazardDetailsSheetState extends State<HazardDetailsSheet> {
  bool _confirming = false;
  bool _confirmed = false;
  String? _error;

  Future<void> _confirm() async {
    if (_confirming || _confirmed) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      await widget.onConfirm();
      if (mounted) {
        setState(() {
          _confirming = false;
          _confirmed = true;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('[HazardDetailsSheet] Confirmation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _confirming = false;
          _error = 'Could not confirm this hazard. Please try again.';
        });
      }
    }
  }

  String _relativeTime(DateTime dateTime) {
    final elapsed = DateTime.now().difference(dateTime);
    if (elapsed.inMinutes < 1) return 'just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours} hr ago';
    return '${elapsed.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = widget.report;
    return Container(
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
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    child: HazardCategoryIcon(
                      category: report.category,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.category.displayLabel,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Reported ${_relativeTime(report.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppSurfaces.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (report.description != null) ...[
                const SizedBox(height: 18),
                Text(report.description!, style: theme.textTheme.bodyLarge),
              ],
              if (report.photoUrl != null) ...[
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    report.photoUrl!,
                    width: double.infinity,
                    height: 210,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 120,
                      alignment: Alignment.center,
                      color: AppSurfaces.innerCard(context),
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('confirm_hazard'),
                  onPressed: _confirming || _confirmed ? null : _confirm,
                  icon: _confirming
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _confirmed ? Icons.check : Icons.thumb_up_outlined,
                        ),
                  label: Text(_confirmed ? 'Confirmed' : 'Still there'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

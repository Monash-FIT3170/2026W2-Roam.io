import 'package:flutter/material.dart';

import '../domain/place_visit_feedback.dart';

/// Compact map help that explains the status shapes on demand.
class PlaceMarkerLegendButton extends StatelessWidget {
  const PlaceMarkerLegendButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 6,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Location marker guide',
        icon: const Icon(Icons.info_outline),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const PlaceMarkerLegend(),
        ),
      ),
    );
  }
}

class PlaceMarkerLegend extends StatelessWidget {
  const PlaceMarkerLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location markers',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const _LegendEntry(
              icon: Icons.radio_button_unchecked,
              title: 'Not visited',
              description:
                  'A hollow marker is a place you have not visited yet.',
            ),
            _LegendEntry(
              icon: Icons.my_location,
              title: 'In range',
              description:
                  'A target ring means you are within ${PlaceVisitFeedback.visitRadiusMetres.round()}m. Tap the place to mark your visit.',
            ),
            const _LegendEntry(
              icon: Icons.check_circle,
              title: 'Visited',
              description:
                  'A filled checkmark means your visit is saved, even when you move away.',
            ),
            Text(
              'Train, tram and bus icons keep their transport symbol and add the same range ring or visited checkmark.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../theme/app_colours.dart';

class JourneysScreen extends StatelessWidget {
  const JourneysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(
              title: 'Journeys',
              subtitle: 'Your past urban explorations and discoveries',
            ),
            const SizedBox(height: 24), // Increased spacing slightly

            // Filter Chips
            _buildFilterChips(),
            const SizedBox(height: 24),
            
            // TODO: Add Journeys List
          ],
        ),
      ),
    );
  }
  Widget _buildFilterChips() {
    final filters = ['All', 'Recent', 'Completed', 'Favorites'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = index == 0; // Mocking 'All' as the active filter
          return Container(
            margin: const EdgeInsets.only(right: 12.0),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.sage : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.sage : AppColors.ink.withOpacity(0.1),
              ),
            ),
            child: Text(
              filters[index],
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.ink.withOpacity(0.6),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        }),
      ),
    );
  }
}
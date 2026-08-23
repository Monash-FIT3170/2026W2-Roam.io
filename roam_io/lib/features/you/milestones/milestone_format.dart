/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Formatting helpers for milestone metric values and thresholds.
 */

import 'milestone_catalog.dart';

String formatMilestoneValue(double value, MilestoneMetricUnit unit) {
  switch (unit) {
    case MilestoneMetricUnit.count:
      return value.round().toString();
    case MilestoneMetricUnit.kilometres:
      if (value >= 100) return '${value.round()} km';
      if (value >= 10) return '${value.toStringAsFixed(1)} km';
      return '${value.toStringAsFixed(2)} km';
    case MilestoneMetricUnit.hours:
      if (value >= 10) return '${value.round()}h';
      return '${value.toStringAsFixed(1)}h';
    case MilestoneMetricUnit.days:
      return '${value.round()}d';
  }
}

String formatMilestoneThreshold(double threshold, MilestoneMetricUnit unit) {
  return formatMilestoneValue(threshold, unit);
}

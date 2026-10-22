/// Consistent, compact dates used by activity and statistics surfaces.
const _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatAppDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day} ${_monthNames[local.month - 1]} ${local.year}';
}

String formatAppDateTime(DateTime value) {
  final local = value.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '${formatAppDate(local)} · $hour:$minute $period';
}

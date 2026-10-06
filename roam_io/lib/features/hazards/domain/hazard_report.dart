import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'hazard_category.dart';

/// A temporary, community-reported map hazard.
class HazardReport {
  const HazardReport({
    required this.id,
    required this.reporterId,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.lastConfirmedAt,
    required this.expiresAt,
    this.description,
    this.photoUrl,
    this.photoStoragePath,
  });

  final String id;
  final String reporterId;
  final HazardCategory category;
  final double latitude;
  final double longitude;
  final String? description;
  final String? photoUrl;
  final String? photoStoragePath;
  final DateTime createdAt;
  final DateTime lastConfirmedAt;
  final DateTime expiresAt;

  LatLng get location => LatLng(latitude, longitude);

  bool isActiveAt(DateTime time) => expiresAt.isAfter(time);

  factory HazardReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw StateError('Hazard ${document.id} has no data');
    }
    return HazardReport(
      id: document.id,
      reporterId: data['reporterId'] as String,
      category: HazardCategory.fromId(data['category'] as String),
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      description: data['description'] as String?,
      photoUrl: data['photoUrl'] as String?,
      photoStoragePath: data['photoStoragePath'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastConfirmedAt: (data['lastConfirmedAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'reporterId': reporterId,
      'category': category.id,
      'latitude': latitude,
      'longitude': longitude,
      if (description != null) 'description': description,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (photoStoragePath != null) 'photoStoragePath': photoStoragePath,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastConfirmedAt': Timestamp.fromDate(lastConfirmedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }
}

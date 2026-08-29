import 'package:cloud_firestore/cloud_firestore.dart';

import '../../profile/domain/home_base.dart';

/// Reads and writes the user's home base on `profiles/{uid}.home_base`.
class HomeBaseService {
  HomeBaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) {
    return _firestore.collection('profiles').doc(uid);
  }

  Future<HomeBase?> getHomeBase(String uid) async {
    final snapshot = await _profileDoc(uid).get();
    final raw = snapshot.data()?['home_base'];
    if (raw is! Map<String, dynamic>) return null;
    return HomeBase.fromMap(raw);
  }

  Stream<HomeBase?> watchHomeBase(String uid) {
    return _profileDoc(uid).snapshots().map((snapshot) {
      final raw = snapshot.data()?['home_base'];
      if (raw is! Map<String, dynamic>) return null;
      return HomeBase.fromMap(raw);
    });
  }

  Future<void> setHomeBase({
    required String uid,
    required double lat,
    required double lng,
    String? label,
  }) async {
    final homeBase = HomeBase(
      lat: lat,
      lng: lng,
      setAt: DateTime.now(),
      label: label,
    );

    await _profileDoc(uid).set(<String, dynamic>{
      'home_base': homeBase.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> clearHomeBase(String uid) async {
    await _profileDoc(uid).update(<String, dynamic>{
      'home_base': FieldValue.delete(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}

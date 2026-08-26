/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Reusable social privacy settings stored on profiles/{uid}. This model is
 *   intentionally small for the private-account phase, but future social
 *   interaction controls can extend it without scattering raw Firestore fields
 *   through widgets.
 */

/// Privacy settings that control social profile access.
class SocialPrivacySettings {
  const SocialPrivacySettings({this.isPrivateAccount = false});

  final bool isPrivateAccount;

  SocialPrivacySettings copyWith({bool? isPrivateAccount}) {
    return SocialPrivacySettings(
      isPrivateAccount: isPrivateAccount ?? this.isPrivateAccount,
    );
  }

  factory SocialPrivacySettings.fromMap(Object? value) {
    if (value is! Map) return const SocialPrivacySettings();
    return SocialPrivacySettings(
      isPrivateAccount: value['isPrivateAccount'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'isPrivateAccount': isPrivateAccount};
  }
}

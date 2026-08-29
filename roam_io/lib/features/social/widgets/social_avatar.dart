/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 9 August 2026
 * Description:
 *   Shared avatar for social/profile surfaces. public_profiles.photoUrl is an
 *   HTTPS Firebase Storage download URL (or rarely gs:// / storage path).
 *   HTTP(S) URLs load via Image.network (same path Settings uses successfully).
 */

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';

typedef SocialAvatarStorageUrlResolver = Future<String> Function(String rawUrl);

class SocialAvatar extends StatefulWidget {
  const SocialAvatar({
    super.key,
    required this.displayName,
    required this.photoUrl,
    this.radius = 24,
    this.borderWidth = 0,
  });

  final String displayName;
  final String? photoUrl;
  final double radius;
  final double borderWidth;

  static SocialAvatarStorageUrlResolver? debugStorageUrlResolverForTests;
  static final Map<String, Future<String?>> _resolvedUrlCache = {};
  static final Set<String> _loggedHosts = <String>{};

  static ImageProvider? imageProviderFor(
    BuildContext context, {
    required String? photoUrl,
    required double radius,
  }) {
    final url = photoUrl?.trim();
    if (url == null || url.isEmpty || !_isNetworkUrl(url)) return null;
    return NetworkImage(url);
  }

  static void precachePhotoUrls(
    BuildContext context,
    Iterable<String?> photoUrls, {
    double radius = 24,
  }) {
    final seen = <String>{};
    for (final rawUrl in photoUrls) {
      final raw = rawUrl?.trim();
      if (raw == null || raw.isEmpty || !seen.add(raw)) continue;
      unawaited(
        _resolvePhotoUrl(raw)
            .then((resolvedUrl) {
              if (!context.mounted ||
                  resolvedUrl == null ||
                  resolvedUrl.isEmpty ||
                  !_isNetworkUrl(resolvedUrl)) {
                return null;
              }
              return precacheImage(NetworkImage(resolvedUrl), context);
            })
            .catchError((Object error) {
              debugPrint('[SocialAvatar] precache failed error=$error');
            }),
      );
    }
  }

  static Future<String?> resolvePhotoUrlForTests(String? photoUrl) {
    return _resolvePhotoUrl(photoUrl);
  }

  static void clearResolvedUrlCacheForTests() {
    _resolvedUrlCache.clear();
    _loggedHosts.clear();
  }

  @override
  State<SocialAvatar> createState() => _SocialAvatarState();

  static Future<String?> _resolvePhotoUrl(String? photoUrl) {
    final raw = photoUrl?.trim();
    if (raw == null || raw.isEmpty) return Future<String?>.value(null);
    if (_isNetworkUrl(raw)) return Future<String?>.value(raw);
    return _resolvedUrlCache.putIfAbsent(raw, () async {
      if (!_isStorageUrlOrPath(raw)) {
        debugPrint(
          '[SocialAvatar] unsupported photoUrl format '
          'format=${_describePhotoUrl(raw)}',
        );
        return null;
      }
      try {
        final resolver =
            debugStorageUrlResolverForTests ?? _resolveFirebaseStorageUrl;
        final resolved = (await resolver(raw)).trim();
        debugPrint(
          '[SocialAvatar] resolved photoUrl rawFormat=${_describePhotoUrl(raw)} '
          'resolvedFormat=${_describePhotoUrl(resolved)}',
        );
        return _isNetworkUrl(resolved) ? resolved : null;
      } on FirebaseException catch (error) {
        debugPrint(
          '[SocialAvatar] Firebase Storage avatar resolve failed '
          'plugin=${error.plugin} code=${error.code} message=${error.message} '
          'rawFormat=${_describePhotoUrl(raw)} error=$error',
        );
        return null;
      } catch (error) {
        debugPrint(
          '[SocialAvatar] avatar resolve failed '
          'rawFormat=${_describePhotoUrl(raw)} error=$error',
        );
        return null;
      }
    });
  }

  static Future<String> _resolveFirebaseStorageUrl(String raw) {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase is not initialized.');
    }
    final storage = FirebaseStorage.instance;
    if (raw.startsWith('gs://')) {
      return storage.refFromURL(raw).getDownloadURL();
    }
    return storage.ref(raw.replaceFirst(RegExp(r'^/+'), '')).getDownloadURL();
  }

  static bool _isNetworkUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  static bool _isStorageUrlOrPath(String value) {
    if (value.startsWith('gs://')) return true;
    final uri = Uri.tryParse(value);
    return uri == null || uri.scheme.isEmpty;
  }

  static String _describePhotoUrl(String value) {
    if (value.isEmpty) return 'empty';
    if (value.startsWith('https://')) return 'https';
    if (value.startsWith('http://')) return 'http';
    if (value.startsWith('gs://')) return 'gs';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme.isEmpty) return 'storage_path';
    return uri.scheme;
  }

  static String _safeHost(String url) {
    return Uri.tryParse(url)?.host ?? '(invalid-host)';
  }

  static void _logAvatarOnce({
    required String url,
    required String phase,
    Object? error,
  }) {
    final host = _safeHost(url);
    final key = '$phase|$host|${url.length}';
    if (!_loggedHosts.add(key)) return;
    debugPrint(
      '[SocialAvatar] $phase format=${_describePhotoUrl(url)} '
      'host=$host length=${url.length}'
      '${error == null ? '' : ' error=$error'}',
    );
  }
}

class _SocialAvatarState extends State<SocialAvatar> {
  Future<String?>? _resolvedUrlFuture;
  String? _rawPhotoUrl;
  String? _directNetworkUrl;

  @override
  void initState() {
    super.initState();
    _configureResolvedUrl();
  }

  @override
  void didUpdateWidget(covariant SocialAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _configureResolvedUrl();
    }
  }

  void _configureResolvedUrl() {
    _rawPhotoUrl = widget.photoUrl?.trim();
    _directNetworkUrl =
        _rawPhotoUrl != null && SocialAvatar._isNetworkUrl(_rawPhotoUrl!)
        ? _rawPhotoUrl
        : null;
    if (_directNetworkUrl != null) {
      SocialAvatar._logAvatarOnce(
        url: _directNetworkUrl!,
        phase: 'paint-https',
      );
    }
    _resolvedUrlFuture = _directNetworkUrl == null
        ? SocialAvatar._resolvePhotoUrl(_rawPhotoUrl)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = widget.displayName.trim().isEmpty
        ? '?'
        : widget.displayName.trim().characters.first;
    final hasRawPhoto = _rawPhotoUrl != null && _rawPhotoUrl!.isNotEmpty;
    final size = widget.radius * 2;

    Widget fallback({required bool awaitingImage}) {
      return Center(
        child: awaitingImage
            ? SizedBox(
                width: widget.radius,
                height: widget.radius,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            : Text(
                initial,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: !hasRawPhoto
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
      );
    }

    Widget image(String url) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        gaplessPlayback: true,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return fallback(awaitingImage: true);
        },
        errorBuilder: (context, error, stackTrace) {
          SocialAvatar._logAvatarOnce(
            url: url,
            phase: 'image-load-failed',
            error: error,
          );
          return fallback(awaitingImage: false);
        },
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: !hasRawPhoto
            ? theme.colorScheme.primary
            : AppSurfaces.softCard(context),
        shape: BoxShape.circle,
        border: widget.borderWidth > 0
            ? Border.all(
                color: theme.colorScheme.primary,
                width: widget.borderWidth,
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: !hasRawPhoto
          ? fallback(awaitingImage: false)
          : _directNetworkUrl != null
          ? image(_directNetworkUrl!)
          : FutureBuilder<String?>(
              future: _resolvedUrlFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return fallback(awaitingImage: true);
                }
                final url = snapshot.data;
                if (url == null || url.isEmpty) {
                  return fallback(awaitingImage: false);
                }
                SocialAvatar._logAvatarOnce(url: url, phase: 'paint-resolved');
                return image(url);
              },
            ),
    );
  }
}

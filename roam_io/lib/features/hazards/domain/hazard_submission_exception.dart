/// User-actionable failures that can occur while submitting a hazard.
enum HazardSubmissionFailure {
  locationServicesDisabled,
  locationPermissionDenied,
  locationUnavailable,
  photoUpload,
  save,
}

class HazardSubmissionException implements Exception {
  const HazardSubmissionException(this.failure, {this.cause});

  final HazardSubmissionFailure failure;
  final Object? cause;

  String get userMessage => switch (failure) {
    HazardSubmissionFailure.locationServicesDisabled =>
      'Please enable location services to report a hazard.',
    HazardSubmissionFailure.locationPermissionDenied =>
      'Please grant location permission to report a hazard.',
    HazardSubmissionFailure.locationUnavailable =>
      'Could not get your current location.',
    HazardSubmissionFailure.photoUpload =>
      'Photo upload failed. Try again or remove the photo.',
    HazardSubmissionFailure.save =>
      'Could not save the hazard report right now.',
  };

  factory HazardSubmissionException.fromLocationError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('location service') && message.contains('disabled')) {
      return HazardSubmissionException(
        HazardSubmissionFailure.locationServicesDisabled,
        cause: error,
      );
    }
    if ((message.contains('permission') && message.contains('denied')) ||
        message.contains('deniedforever')) {
      return HazardSubmissionException(
        HazardSubmissionFailure.locationPermissionDenied,
        cause: error,
      );
    }
    return HazardSubmissionException(
      HazardSubmissionFailure.locationUnavailable,
      cause: error,
    );
  }

  @override
  String toString() => 'HazardSubmissionException($failure, cause: $cause)';
}

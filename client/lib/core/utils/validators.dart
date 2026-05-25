class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validateRequired(String? value, {String? fieldName}) {
    final name = fieldName ?? 'Field';
    if (value == null || value.trim().isEmpty) {
      return '$name is required';
    }
    return null;
  }

  static String? validatePieceName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Piece name is required';
    }
    if (value.trim().length < 2) {
      return 'Piece name must be at least 2 characters';
    }
    if (value.trim().length > 200) {
      return 'Piece name must be under 200 characters';
    }
    return null;
  }

  static String? validateDuration(Duration? value) {
    if (value == null || value.inSeconds <= 0) {
      return 'Duration must be positive';
    }
    return null;
  }

  static String? validateScoreUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Score URL is required';
    }
    final urlRegex = RegExp(
      r'^(https?|s3|file)://',
    );
    if (!urlRegex.hasMatch(value)) {
      return 'Enter a valid URL or file path';
    }
    return null;
  }

  static String? validateAnnotationLayerId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Layer ID is required';
    }
    return null;
  }
}

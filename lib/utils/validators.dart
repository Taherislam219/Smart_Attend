class Validators {
  Validators._();

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your full name';
    if (!RegExp(r"^[\p{L}][\p{L} .'-]{1,79}$", unicode: true).hasMatch(text)) {
      return 'Use 2-80 letters and common name punctuation';
    }
    return null;
  }

  static String? studentId(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your university student ID';
    if (!RegExp(r'^\d{8,20}$').hasMatch(text)) {
      return 'Use 8-20 digits (keep leading zeros)';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email';
    if (!RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
        .hasMatch(text)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }
}

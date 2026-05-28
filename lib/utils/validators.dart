class Validators {
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter a valid Pakistani number (03XXXXXXXXX)';
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Enter a valid Pakistani number (03XXXXXXXXX)';
    }
    if (cleaned.length != 11) {
      return 'Enter a valid Pakistani number (03XXXXXXXXX)';
    }
    if (!cleaned.startsWith('03')) {
      return 'Enter a valid Pakistani number (03XXXXXXXXX)';
    }
    return null;
  }
}

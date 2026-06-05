import 'package:flutter/widgets.dart';

/// Screen-size helpers built on [MediaQuery] for adapting layout, typography,
/// and spacing across phones and tablets.
class Responsive {
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isSmallPhone(BuildContext context) => screenWidth(context) < 360;

  static bool isMediumPhone(BuildContext context) =>
      screenWidth(context) >= 360 && screenWidth(context) < 414;

  static bool isLargePhone(BuildContext context) =>
      screenWidth(context) >= 414 && screenWidth(context) < 768;

  static bool isTablet(BuildContext context) => screenWidth(context) >= 768;

  /// Scales a base font size down on small phones and up on tablets.
  static double fontSize(BuildContext context, double size) {
    if (isSmallPhone(context)) return size * 0.85;
    if (isTablet(context)) return size * 1.2;
    return size;
  }

  /// Standard screen edge padding for the current size class.
  static double padding(BuildContext context) {
    if (isSmallPhone(context)) return 12.0;
    if (isTablet(context)) return 24.0;
    return 16.0;
  }

  static double cardHeight(BuildContext context) {
    if (isSmallPhone(context)) return 80.0;
    if (isTablet(context)) return 120.0;
    return 90.0;
  }

  static double avatarRadius(BuildContext context) {
    if (isSmallPhone(context)) return 20.0;
    if (isTablet(context)) return 35.0;
    return 25.0;
  }
}

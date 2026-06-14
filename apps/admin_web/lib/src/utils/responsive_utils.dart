import 'package:flutter/material.dart';

/// Responsive breakpoints
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Check if current screen is mobile
bool isMobile(BuildContext context) =>
    MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;

/// Check if current screen is tablet
bool isTablet(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return width >= ResponsiveBreakpoints.mobile && width < ResponsiveBreakpoints.desktop;
}

/// Check if current screen is desktop
bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktop;

/// Check if current screen is tablet or smaller
bool isTabletOrBelow(BuildContext context) =>
    MediaQuery.of(context).size.width < ResponsiveBreakpoints.desktop;

/// Returns appropriate padding based on screen size
EdgeInsets responsivePadding(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < ResponsiveBreakpoints.mobile) return const EdgeInsets.all(12);
  if (width < ResponsiveBreakpoints.tablet) return const EdgeInsets.all(16);
  if (width < ResponsiveBreakpoints.desktop) return const EdgeInsets.all(20);
  return const EdgeInsets.all(24);
}

/// Returns responsive padding uniformly scaled by [factor] (e.g. 0.8 for tighter cards).
EdgeInsets responsivePaddingScaled(BuildContext context, double factor) {
  final base = responsivePadding(context);
  if (base.left == base.right &&
      base.left == base.top &&
      base.left == base.bottom) {
    return EdgeInsets.all(base.left * factor);
  }
  return EdgeInsets.fromLTRB(
    base.left * factor,
    base.top * factor,
    base.right * factor,
    base.bottom * factor,
  );
}

/// Returns appropriate horizontal padding
double responsiveHPadding(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < ResponsiveBreakpoints.mobile) return 12;
  if (width < ResponsiveBreakpoints.tablet) return 16;
  if (width < ResponsiveBreakpoints.desktop) return 20;
  return 24;
}

/// Returns the sidebar width based on screen size
double sidebarWidth(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < ResponsiveBreakpoints.mobile) return 0; // hidden
  if (width < ResponsiveBreakpoints.tablet) return 72; // collapsed
  return 260; // expanded
}

/// Returns number of grid columns based on screen width
int gridColumns(BuildContext context, {int mobile = 1, int tablet = 2, int desktop = 3, int wide = 4}) {
  final width = MediaQuery.of(context).size.width;
  if (width < ResponsiveBreakpoints.mobile) return mobile;
  if (width < ResponsiveBreakpoints.tablet) return tablet;
  if (width < ResponsiveBreakpoints.desktop) return desktop;
  return wide;
}

/// Responsive text scale factor
double responsiveTextScale(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < ResponsiveBreakpoints.mobile) return 0.85;
  if (width < ResponsiveBreakpoints.tablet) return 0.9;
  return 1.0;
}

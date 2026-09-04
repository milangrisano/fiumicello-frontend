/// Central responsive breakpoints for the whole app.
///
/// Screen width ranges:
///  - mobile  : width < 800
///  - tablet  : 800 <= width < 1200
///  - desktop : width >= 1200
class Breakpoints {
  Breakpoints._();

  static const double mobileMax = 800;
  static const double tabletMax = 1200;

  static bool isMobile(double width) => width < mobileMax;
  static bool isTablet(double width) => width >= mobileMax && width < tabletMax;
  static bool isDesktop(double width) => width >= tabletMax;
}
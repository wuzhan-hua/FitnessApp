import 'package:flutter/widgets.dart';

class AppTextScale {
  const AppTextScale._();

  static const double normalScale = 1.0;
  static const double largePhoneScale = 1.1;
  static const double _largePhoneShortestSideThreshold = 430;
  static const double _tabletShortestSideThreshold = 600;

  static double resolve(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    if (shortestSide >= _tabletShortestSideThreshold) {
      return normalScale;
    }
    if (shortestSide >= _largePhoneShortestSideThreshold) {
      return largePhoneScale;
    }
    return normalScale;
  }
}

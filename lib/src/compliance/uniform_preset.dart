import 'package:flutter/material.dart';

/// Pre-configured delivery company uniform color definitions.
enum UniformPreset {
  /// Zepto delivery uniform (distinctive purple / violet).
  zeptoPurple,

  /// Swiggy delivery uniform (vibrant orange).
  swiggyOrange,

  /// Zomato delivery uniform (deep red).
  zomatoRed,

  /// Blinkit delivery uniform (bright yellow).
  blinkitYellow,

  /// Custom brand uniform color.
  custom,
}

extension UniformPresetExtension on UniformPreset {
  /// Target primary brand color.
  Color get primaryColor {
    switch (this) {
      case UniformPreset.zeptoPurple:
        return const Color(0xFF5200FF);
      case UniformPreset.swiggyOrange:
        return const Color(0xFFFC8019);
      case UniformPreset.zomatoRed:
        return const Color(0xFFCB202D);
      case UniformPreset.blinkitYellow:
        return const Color(0xFFF4C430);
      case UniformPreset.custom:
        return const Color(0xFF2196F3);
    }
  }

  /// Display name of the uniform brand.
  String get displayName {
    switch (this) {
      case UniformPreset.zeptoPurple:
        return 'Zepto Purple Uniform';
      case UniformPreset.swiggyOrange:
        return 'Swiggy Orange Uniform';
      case UniformPreset.zomatoRed:
        return 'Zomato Red Uniform';
      case UniformPreset.blinkitYellow:
        return 'Blinkit Yellow Uniform';
      case UniformPreset.custom:
        return 'Custom Uniform';
    }
  }

  /// Target Hue range in HSV color space [0..360].
  List<double> get targetHueRange {
    switch (this) {
      case UniformPreset.zeptoPurple:
        return const <double>[260.0, 295.0];
      case UniformPreset.swiggyOrange:
        return const <double>[18.0, 36.0];
      case UniformPreset.zomatoRed:
        return const <double>[340.0, 15.0];
      case UniformPreset.blinkitYellow:
        return const <double>[42.0, 62.0];
      case UniformPreset.custom:
        return const <double>[200.0, 240.0];
    }
  }
}

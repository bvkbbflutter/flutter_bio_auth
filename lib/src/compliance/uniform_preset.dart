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

  /// Hex representation of the target uniform color.
  String get primaryColorHex {
    switch (this) {
      case UniformPreset.zeptoPurple:
        return '#5200FF';
      case UniformPreset.swiggyOrange:
        return '#FC8019';
      case UniformPreset.zomatoRed:
        return '#CB202D';
      case UniformPreset.blinkitYellow:
        return '#F4C430';
      case UniformPreset.custom:
        return '#2196F3';
    }
  }

  /// Accurately checks whether an observed clothing color matches this uniform preset.
  bool matchesColor(Color observedColor, {double tolerance = 0.25}) {
    final HSVColor hsv = HSVColor.fromColor(observedColor);
    // Dark black, white, or washed-out grey clothing cannot match brand colored uniforms
    if (hsv.saturation < 0.25 || hsv.value < 0.15) {
      return false;
    }
    final List<double> range = targetHueRange;
    final double h = hsv.hue;
    if (range[0] <= range[1]) {
      return h >= (range[0] - 10.0) && h <= (range[1] + 10.0);
    } else {
      // Wraps around 360 degrees (e.g. Red)
      return h >= (range[0] - 10.0) || h <= (range[1] + 10.0);
    }
  }

  /// Describes the common human-readable color family of an observed color.
  static String describeColor(Color color) {
    final HSVColor hsv = HSVColor.fromColor(color);
    if (hsv.value < 0.18) return 'Dark / Black';
    if (hsv.saturation < 0.18 && hsv.value > 0.70) return 'White / Off-White';
    if (hsv.saturation < 0.20) return 'Grey / Neutral';
    final double h = hsv.hue;
    if (h >= 345 || h < 15) return 'Red';
    if (h >= 15 && h < 42) return 'Orange';
    if (h >= 42 && h < 68) return 'Yellow';
    if (h >= 68 && h < 165) return 'Green';
    if (h >= 165 && h < 195) return 'Cyan';
    if (h >= 195 && h < 255) return 'Blue';
    if (h >= 255 && h < 295) return 'Purple / Violet';
    if (h >= 295 && h < 345) return 'Pink / Magenta';
    return 'Colored';
  }

  /// Converts a Color to a hex representation (e.g. #5200FF).
  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
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

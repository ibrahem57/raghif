import 'package:flutter/material.dart';

/// 8dp-grid shape scale per UI_SPEC.md: small=chips/badges, medium=buttons/inputs, large=cards.
class AppShapes {
  AppShapes._();

  static const small = BorderRadius.all(Radius.circular(8));
  static const medium = BorderRadius.all(Radius.circular(16));
  static const large = BorderRadius.all(Radius.circular(24));
}

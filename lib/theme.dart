import 'package:flutter/material.dart';

class LFC {
  // Colors
  static const Color red       = Color(0xFFC8102E);
  static const Color redDark   = Color(0xFFAA0E26);
  static const Color redDarker = Color(0xFF8A0B1E);
  static const Color redLight  = Color(0xFFE8384F);
  static const Color gold      = Color(0xFFD4AF37);
  static const Color goldDim   = Color(0x1AD4AF37);
  static const Color green     = Color(0xFF4CAF50);
  static const Color bg2       = Color(0xFF1A1A2E);
  static const Color card      = Color(0xFF16213E);
  static const Color text      = Color(0xFFE8E8E8);
  static const Color text2     = Color(0xFFB0B0C0);
  static const Color muted     = Color(0xFF6B6B8A);
  static const Color border    = Color(0xFF2A2A4A);

  static const List<String> currencies = ['USD', 'EUR', 'GBP'];

  static String fmtDate(String d) {
    if (d.length != 10) return d;
    final parts = d.split('-');
    if (parts.length != 3) return d;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  static String fmtPrice(double? price, int cur) {
    if (price == null || price <= 0) return '—';
    final symbol = cur == 0 ? '\$' : cur == 1 ? '€' : '£';
    return '$symbol${price.toStringAsFixed(2)}';
  }
}

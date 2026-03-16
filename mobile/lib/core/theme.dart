import 'package:flutter/material.dart';

// 해먹당 브랜드 색상 (웹 app.css CSS 변수 1:1 대응)
const Color primaryColor    = Color(0xFFC4704B); // --color-terracotta (웹 주요 포인트색)
const Color paperColor      = Color(0xFFFAF8F5); // --color-paper
const Color creamColor      = Color(0xFFF5F0E8); // --color-cream
const Color warmBrownColor  = Color(0xFF8B7355); // --color-warm-brown (기본 텍스트색)
const Color softBrownColor  = Color(0xFFA89580); // --color-soft-brown (보조 텍스트색)
const Color lightLineColor  = Color(0xFFE0D8CC); // --color-light-line
const Color darkColor       = Color(0xFF2C1810); // 강조 텍스트 (웹 없음, 헤더/제목용)

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      surface: paperColor,
      onSurface: darkColor,
    ),
    scaffoldBackgroundColor: paperColor,
    fontFamily: 'Pretendard', // 추후 폰트 추가 시 활성화
    appBarTheme: const AppBarTheme(
      backgroundColor: paperColor,
      foregroundColor: darkColor,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: paperColor,
      selectedItemColor: primaryColor,
      unselectedItemColor: softBrownColor,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: creamColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    dividerColor: lightLineColor,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: lightLineColor, width: 1),
      ),
    ),
  );
}

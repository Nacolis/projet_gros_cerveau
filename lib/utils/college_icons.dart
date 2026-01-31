import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Maps college names to their corresponding SVG icon filenames.
/// Icons should be placed in assets/icons/outline/ and assets/icons/solid/
class CollegeIcons {
  CollegeIcons._();

  /// Maps college names to SVG filenames (without path)
  static const Map<String, String> _collegeIconMap = {
    'Santé pub': 'public health.svg',
    'Med légale': 'pathology.svg',
    'Géria - MPR': 'geriatric medicine.svg',
    'Humanité': 'science.svg',
    'Gynéco': 'obstetrics.svg',
    'Génétique': 'immunology.svg',
    'Ped': 'pediatrics.svg',
    'Uro': 'urology.svg',
    'MPR': 'physical therapy.svg',
    'Psy': 'psychology.svg',
    'Ophtalmo': 'ophthalmology.svg',
    'ORL': 'ear nose and throat.svg',
    'Neuro': 'neurology.svg',
    'Rhumato': 'rheumatology.svg',
    'Dermato': 'dermatology.svg',
    'Géria': 'geriatric medicine.svg',
    'Géria, Soins P': 'geriatric medicine.svg',
    'Anesth': 'anesthesiology.svg',
    'Soins pall': 'family medicine.svg',
    'Infectio': 'immunology.svg',
    'Réa': 'emergency care.svg',
    'HGE': 'gastroenterology.svg',
    'Med Travail': 'public health.svg',
    'Pneumo': 'pulmonology.svg',
    'Med Int': 'internal medicine.svg',
    'Néphro': 'nephrology.svg',
    'Ortho': 'orthopedics.svg',
    'Néphro-Uro': 'nephrology.svg',
    'Hémato': 'oncology.svg',
    'Cardio': 'cardiology.svg',
    'Cardio-Endoc': 'cardiology.svg',
    'Cardio - Pneumo': 'cardiology.svg',
    'Chir vasc': 'surgery.svg',
    'Endoc': 'internal medicine.svg',
    'Endoc - Nutrition': 'natural medicine.svg',
    'Nutrition': 'natural medicine.svg',
    'Gastro': 'gastroenterology.svg',
    'Chir visc': 'surgery.svg',
    'Cancéro': 'oncology.svg',
    'CMF': 'surgery.svg',
    'Thérapeutique': 'pharmacy 1.svg',
    'Urgences': 'emergency care.svg',
    'ORL - CMF': 'ear nose and throat.svg',
    'Chir Dig': 'surgery.svg',
    'Réa - Urgences': 'emergency care.svg',
    'Santé Pub': 'public health.svg',
  };

  /// Get the SVG icon path for a college name
  /// [collegeName] The name of the college
  /// [solid] Whether to use the solid variant (default: false for outline)
  static String getIconPath(String? collegeName, {bool solid = false}) {
    final folder = solid ? 'solid' : 'outline';
    final filename = _collegeIconMap[collegeName] ?? 'internal medicine.svg';
    return 'assets/icons/$folder/$filename';
  }

  /// Get just the filename for a college
  static String? getIconFilename(String? collegeName) {
    return _collegeIconMap[collegeName];
  }

  /// Fallback to Material Icons when SVG not available or for simple use
  static IconData getIcon(String? collegeName) {
    if (collegeName == null) return Icons.local_hospital;
    
    // Fallback mapping for Material icons
    const fallbackMap = <String, IconData>{
      'Cardio': Icons.favorite,
      'Cardio-Endoc': Icons.favorite,
      'Cardio - Pneumo': Icons.favorite,
      'Neuro': Icons.psychology,
      'Pneumo': Icons.air,
      'Dermato': Icons.face,
      'Ophtalmo': Icons.visibility,
      'ORL': Icons.hearing,
      'ORL - CMF': Icons.hearing,
      'Psy': Icons.self_improvement,
      'Ped': Icons.child_care,
      'Géria': Icons.elderly,
      'Géria - MPR': Icons.elderly,
      'Géria, Soins P': Icons.elderly,
      'Urgences': Icons.local_hospital,
      'Réa': Icons.monitor_heart,
      'Réa - Urgences': Icons.monitor_heart,
      'Cancéro': Icons.biotech,
      'Gynéco': Icons.pregnant_woman,
      'Ortho': Icons.accessibility_new,
      'Gastro': Icons.restaurant,
      'HGE': Icons.restaurant,
      'Néphro': Icons.water_drop,
      'Néphro-Uro': Icons.water_drop,
      'Uro': Icons.water_drop,
      'Hémato': Icons.bloodtype,
      'Infectio': Icons.coronavirus,
      'Rhumato': Icons.accessibility,
      'Endoc': Icons.science,
      'Endoc - Nutrition': Icons.science,
      'Nutrition': Icons.restaurant_menu,
      'Anesth': Icons.medical_services,
      'Santé pub': Icons.public,
      'Santé Pub': Icons.public,
      'Med Travail': Icons.public,
      'Med légale': Icons.gavel,
      'Génétique': Icons.hub,
      'MPR': Icons.sports_gymnastics,
      'Soins pall': Icons.volunteer_activism,
      'Med Int': Icons.local_hospital,
      'Chir vasc': Icons.content_cut,
      'Chir visc': Icons.content_cut,
      'Chir Dig': Icons.content_cut,
      'CMF': Icons.content_cut,
      'Thérapeutique': Icons.medication,
      'Humanité': Icons.school,
    };

    return fallbackMap[collegeName] ?? Icons.local_hospital;
  }

  /// Get a color for a college (based on name hash for consistency)
  static Color getColor(String collegeName) {
    final colors = [
      const Color(0xFFD4707A), // Dusty rose
      const Color(0xFF7CB98B), // Soft green
      const Color(0xFFE5A85C), // Soft orange
      const Color(0xFF7BA3CB), // Soft blue
      const Color(0xFF9B7CB5), // Soft purple
      const Color(0xFF6BADA6), // Teal
      const Color(0xFFD69B6B), // Terracotta
      const Color(0xFF8B9BC8), // Lavender
      const Color(0xFFCB7B9B), // Pink
      const Color(0xFF7BC8B5), // Mint
    ];
    
    final hash = collegeName.hashCode.abs();
    return colors[hash % colors.length];
  }

  /// Get unique list of all SVG filenames needed
  static Set<String> getAllIconFilenames() {
    return _collegeIconMap.values.toSet();
  }

  /// Build an SVG icon widget for a college
  /// [collegeName] The name of the college
  /// [size] The size of the icon (default: 24)
  /// [color] The color of the icon (optional, uses colorFilter)
  /// [solid] Whether to use the solid variant (default: false for outline)
  static Widget buildIcon(
    String? collegeName, {
    double size = 24,
    Color? color,
    bool solid = false,
  }) {
    final path = getIconPath(collegeName, solid: solid);
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: color != null 
          ? ColorFilter.mode(color, BlendMode.srcIn) 
          : null,
    );
  }
}

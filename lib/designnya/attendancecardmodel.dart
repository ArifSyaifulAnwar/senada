import 'package:flutter/material.dart';

class AttendanceCardModel {
  final int id;
  final String icon;
  final String iconColor;
  final String title;
  String mainText;
  String subText;
  final int urutan;

  AttendanceCardModel({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.mainText,
    required this.subText,
    required this.urutan,
  });

  factory AttendanceCardModel.fromJson(Map<String, dynamic> json) {
    return AttendanceCardModel(
      id: json['Id'] ?? 0,
      icon: json['Icon'] ?? '',
      iconColor: json['IconColor'] ?? '',
      title: json['Title'] ?? '',
      mainText: json['MainText'] ?? '',
      subText: json['SubText'] ?? '',
      urutan: json['Urutan'] ?? 0,
    );
  }

  IconData getIconData() {
    switch (icon) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'coffee':
        return Icons.coffee;
      case 'calendar':
        return Icons.calendar_today;
      default:
        return Icons.help_outline;
    }
  }

  Color getIconColor() {
    switch (iconColor.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'green':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

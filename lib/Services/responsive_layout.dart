import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return mobile;
        } else {
          return desktop;
        }
      },
    );
  }
}

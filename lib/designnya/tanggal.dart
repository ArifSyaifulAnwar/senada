// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class TanggalanHorizontal extends StatefulWidget {
  const TanggalanHorizontal({super.key});

  @override
  State<TanggalanHorizontal> createState() => _TanggalanHorizontalState();
}

class _TanggalanHorizontalState extends State<TanggalanHorizontal> {
  late ScrollController _scrollController;
  late DateTime _today;
  late List<DateTime> _dates;
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _dates = _generateDatesForCurrentMonth();
    _scrollController = ScrollController();

    initializeDateFormatting('id', null).then((_) {
      setState(() => _localeInitialized = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<DateTime> _generateDatesForCurrentMonth() {
    final lastDay = DateTime(_today.year, _today.month + 1, 0);
    return List.generate(
      lastDay.day,
      (i) => DateTime(_today.year, _today.month, i + 1),
    );
  }

  void _scrollToToday() {
    final index = _today.day - 1;
    const double itemWidthWithMargin = 72;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        index * itemWidthWithMargin,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildItem(DateTime date, double itemWidth) {
    final isToday = date.day == _today.day;
    return Container(
      width: itemWidth,
      height: 64,
      decoration: BoxDecoration(
        color: isToday ? Colors.blue : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isToday ? Colors.blue : Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('dd', 'id').format(date),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isToday ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            DateFormat('E', 'id').format(date),
            style: TextStyle(
              color: isToday ? Colors.white : Colors.black54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_localeInitialized) {
      return const SizedBox(
        height: 64,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWeb = screenWidth >= 768;

    // ── WEB: Wrap grid, semua tanggal terlihat tanpa scroll ──
    if (isWeb) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _dates.map((date) => _buildItem(date, 52)).toList(),
      );
    }

    // ── MOBILE: ListView horizontal scroll (perilaku asli) ──
    const double horizontalPadding = 16.0;
    const double itemMargin = 6.0;
    final availableWidth =
        screenWidth - (horizontalPadding * 2) - (itemMargin * 2 * 5);
    final itemWidth = availableWidth / 5;

    return SizedBox(
      height: 80,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _dates.length,
        padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemBuilder: (context, index) {
          final date = _dates[index];
          return Container(
            margin: const EdgeInsets.symmetric(
              horizontal: itemMargin,
              vertical: 8,
            ),
            child: _buildItem(date, itemWidth),
          );
        },
      ),
    );
  }
}

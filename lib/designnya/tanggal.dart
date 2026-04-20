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
      setState(() {
        _localeInitialized = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToToday();
      });
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
      (index) => DateTime(_today.year, _today.month, index + 1),
    );
  }

  void _scrollToToday() {
    final index = _today.day - 1;
    const double itemWidthWithMargin = 72; // asumsi awal
    _scrollController.animateTo(
      index * itemWidthWithMargin,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_localeInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 16.0;
    const itemMargin = 6.0;

    // Hitung lebar item proporsional
    // misalnya muat ~5 item dengan margin & padding
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
          final isToday = date.day == _today.day;

          return Container(
            width: itemWidth,
            margin: const EdgeInsets.symmetric(
              horizontal: itemMargin,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isToday ? Colors.blue : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd', 'id').format(date),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('E', 'id').format(date),
                  style: TextStyle(
                    color: isToday ? Colors.white : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

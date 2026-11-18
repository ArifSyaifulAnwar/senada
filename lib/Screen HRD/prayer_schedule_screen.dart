import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Services/prayer_schedule_service.dart';
import 'doa_karyawan_screen.dart';

class PrayerScheduleScreen extends StatefulWidget {
  const PrayerScheduleScreen({super.key});

  @override
  State<PrayerScheduleScreen> createState() => _PrayerScheduleScreenState();
}

class _PrayerScheduleScreenState extends State<PrayerScheduleScreen> {
  static const _prayers = {
    'SUBUH': 'Subuh',
    'ZUHUR': 'Zuhur',
    'ASAR': 'Asar',
    'MAGRIB': 'Magrib',
    'ISYA': 'Isya',
  };
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  List<DoaKaryawanItem> _employees = [];
  final Map<String, PrayerScheduleEntry> _entries = {};
  final Map<String, String> _azan = {};
  final Map<String, String> _imam = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _employeeError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEmployees());
    unawaited(_loadSchedule());
  }

  Future<void> _loadEmployees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('UserID') ?? '';
      if (userId.isEmpty) {
        throw StateError('Sesi HRD tidak ditemukan. Silakan login ulang.');
      }
      final employees = await DoaService.getKaryawan(userId);
      if (mounted) {
        setState(() {
          _employees = employees;
          _employeeError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _employeeError = error.toString());
    }
  }

  Future<void> _loadSchedule() async {
    final date = _date;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await PrayerScheduleService.list(date);
      if (!mounted || date != _date) return;
      setState(() {
        _entries
          ..clear()
          ..addEntries(entries.map((e) => MapEntry(e.prayerCode, e)));
        _azan
          ..clear()
          ..addEntries(
            entries.map((e) => MapEntry(e.prayerCode, e.muadzinUserId)),
          );
        _imam
          ..clear()
          ..addEntries(
            entries.map((e) => MapEntry(e.prayerCode, e.imamUserId)),
          );
      });
    } catch (error) {
      if (mounted && date == _date) setState(() => _error = error.toString());
    } finally {
      if (mounted && date == _date) setState(() => _loading = false);
    }
  }

  Future<void> _chooseDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (chosen == null || !mounted || chosen == _date) return;
    setState(() => _date = chosen);
    await _loadSchedule();
  }

  String _name(String? id) {
    if (id == null) return 'Pilih karyawan';
    for (final employee in _employees) {
      if (employee.userId == id) return employee.name;
    }
    return id;
  }

  Future<void> _select(String code, bool isAzan) async {
    final selected = await showDialog<DoaKaryawanItem>(
      context: context,
      builder: (dialogContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, update) {
            final search = query.toLowerCase();
            final filtered = _employees
                .where(
                  (e) =>
                      e.name.toLowerCase().contains(search) ||
                      (e.organization ?? '').toLowerCase().contains(search),
                )
                .toList();
            return AlertDialog(
              title: Text(isAzan ? 'Pilih petugas azan' : 'Pilih imam'),
              content: SizedBox(
                width: 420,
                height: MediaQuery.sizeOf(context).height * 0.5,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Cari nama karyawan',
                      ),
                      onChanged: (text) => update(() => query = text),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final e = filtered[index];
                          return ListTile(
                            dense: true,
                            title: Text(e.name),
                            subtitle: e.organization == null
                                ? null
                                : Text(e.organization!),
                            onTap: () => Navigator.pop(dialogContext, e),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => (isAzan ? _azan : _imam)[code] = selected.userId);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _saveAll() async {
    final changed = _prayers.keys
        .where(
          (code) =>
              _azan[code] != _entries[code]?.muadzinUserId ||
              _imam[code] != _entries[code]?.imamUserId,
        )
        .toList();
    if (changed.isEmpty) return _message('Belum ada perubahan jadwal.');
    final incomplete = changed
        .where((code) => _azan[code] == null || _imam[code] == null)
        .toList();
    if (incomplete.isNotEmpty) {
      return _message(
        'Lengkapi azan dan imam untuk ${incomplete.map((e) => _prayers[e]).join(', ')}.',
      );
    }
    final date = _date;
    setState(() => _saving = true);
    final results = await Future.wait(
      changed.map((code) async {
        try {
          await PrayerScheduleService.save(
            date: date,
            prayerCode: code,
            muadzinUserId: _azan[code]!,
            imamUserId: _imam[code]!,
          );
          return null;
        } catch (error) {
          return '${_prayers[code]}: $error';
        }
      }),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final failures = results.whereType<String>().toList();
    await _loadSchedule();
    if (!mounted) return;
    _message(
      failures.isEmpty
          ? '${changed.length} jadwal berhasil disimpan.'
          : 'Sebagian jadwal gagal: ${failures.join('; ')}',
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Jadwal Azan & Imam',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          OutlinedButton.icon(
            onPressed: _saving ? null : _chooseDate,
            icon: const Icon(Icons.event),
            label: Text(DateFormat('dd MMMM yyyy', 'id').format(_date)),
          ),
          IconButton(
            onPressed: _saving
                ? null
                : () {
                    unawaited(_loadEmployees());
                    unawaited(_loadSchedule());
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text('Isi beberapa waktu salat lalu simpan sekaligus.'),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null)
        Text(
          'Data belum dapat dimuat: $_error',
          style: const TextStyle(color: Colors.red),
        ),
      if (_employeeError != null)
        Text(_employeeError!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 12),
      for (final prayer in _prayers.entries)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayer.value,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving || _loading || _employees.isEmpty
                          ? null
                          : () => _select(prayer.key, true),
                      icon: const Icon(Icons.campaign_outlined),
                      label: Text('Azan: ${_name(_azan[prayer.key])}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving || _loading || _employees.isEmpty
                          ? null
                          : () => _select(prayer.key, false),
                      icon: const Icon(Icons.person_outline),
                      label: Text('Imam: ${_name(_imam[prayer.key])}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _saving || _loading || _employees.isEmpty
              ? null
              : _saveAll,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Menyimpan...' : 'Simpan jadwal'),
        ),
      ),
    ],
  );
}

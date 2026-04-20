// add_education_experience_screen.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Education {
  final String institution;
  final String degree;
  final String field;
  final String period;
  final String? grade;
  final String type;

  Education({
    required this.institution,
    required this.degree,
    required this.field,
    required this.period,
    this.grade,
    required this.type,
  });
}

class Experience {
  final String company;
  final String position;
  final String period;
  final String? description;
  final String type;

  Experience({
    required this.company,
    required this.position,
    required this.period,
    this.description,
    required this.type,
  });
}

class AddEducationExperienceScreen extends StatefulWidget {
  final String type;
  final Education? educationToEdit;
  final Experience? experienceToEdit;

  const AddEducationExperienceScreen({
    super.key,
    required this.type,
    this.educationToEdit,
    this.experienceToEdit,
  });

  @override
  _AddEducationExperienceScreenState createState() =>
      _AddEducationExperienceScreenState();
}

class _AddEducationExperienceScreenState
    extends State<AddEducationExperienceScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  // Controllers for Education
  final TextEditingController _institutionController = TextEditingController();
  final TextEditingController _degreeController = TextEditingController();
  final TextEditingController _fieldController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();

  // Controllers for Experience
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Form state
  bool _isLoading = false;
  bool _isCurrentlyStudying = false;
  bool _isCurrentlyWorking = false;

  // Education degree options
  final List<String> _educationDegrees = [
    'SD',
    'SMP',
    'SMA/SMK',
    'Diploma I (D1)',
    'Diploma II (D2)',
    'Diploma III (D3)',
    'Diploma IV (D4)',
    'Sarjana (S1)',
    'Magister (S2)',
    'Doktor (S3)',
  ];

  bool get isEducation => widget.type == 'education';
  bool get isEditMode =>
      (isEducation && widget.educationToEdit != null) ||
      (!isEducation && widget.experienceToEdit != null);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _initializeData();
  }

  Future<void> _initializeData() async {
    // If edit mode, populate fields
    if (isEditMode) {
      _populateEditData();
    }

    _controller.forward();
  }

  void _populateEditData() {
    if (isEducation && widget.educationToEdit != null) {
      final education = widget.educationToEdit!;
      _institutionController.text = education.institution;
      _degreeController.text = education.degree;
      _fieldController.text = education.field;
      // Parse period like "2018 - 2022" or "2018 - Sekarang"
      final periods = education.period.split(' - ');
      if (periods.length == 2) {
        _startDateController.text = periods[0];
        if (periods[1] != 'Sekarang') {
          _endDateController.text = periods[1];
        } else {
          _isCurrentlyStudying = true;
        }
      }
      if (education.grade != null) {
        _gradeController.text = education.grade!;
      }
    } else if (!isEducation && widget.experienceToEdit != null) {
      final experience = widget.experienceToEdit!;
      _companyController.text = experience.company;
      _positionController.text = experience.position;
      // Parse period like "Jan 2023 - Sekarang"
      final periods = experience.period.split(' - ');
      if (periods.length == 2) {
        _startDateController.text = periods[0];
        if (periods[1] != 'Sekarang') {
          _endDateController.text = periods[1];
        } else {
          _isCurrentlyWorking = true;
        }
      }
      if (experience.description != null) {
        _descriptionController.text = experience.description!;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _institutionController.dispose();
    _degreeController.dispose();
    _fieldController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _gradeController.dispose();
    _companyController.dispose();
    _positionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Modern Input Decoration
  InputDecoration _buildModernInputDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: const Color(0xFF007AFF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red[400]!, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red[400]!, width: 2),
      ),
      labelStyle: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      errorStyle: TextStyle(
        color: Colors.red[600],
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    return null;
  }

  String? _validateGrade(String? value) {
    if (value == null || value.isEmpty) return null;

    double? grade = double.tryParse(value);
    if (grade == null) {
      return 'Format nilai tidak valid';
    }

    if (grade < 0 || grade > 4.0) {
      return 'Nilai harus antara 0.0 - 4.0';
    }

    return null;
  }

  Future<void> _selectYear(TextEditingController controller) async {
    final int currentYear = DateTime.now().year;
    final int? selectedYear = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pilih Tahun'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: 50, // Show last 50 years
              itemBuilder: (context, index) {
                final year = currentYear - index;
                return ListTile(
                  title: Text(year.toString()),
                  onTap: () => Navigator.pop(context, year),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal'),
            ),
          ],
        );
      },
    );

    if (selectedYear != null) {
      setState(() {
        controller.text = selectedYear.toString();
      });
    }
  }

  Future<void> _selectMonthYear(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF007AFF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      setState(() {
        controller.text = "${months[picked.month - 1]} ${picked.year}";
      });
    }
  }

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulate API call
      await Future.delayed(Duration(seconds: 2));

      setState(() {
        _isLoading = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text(
                isEditMode
                    ? '${isEducation ? 'Pendidikan' : 'Pengalaman'} berhasil diperbarui'
                    : '${isEducation ? 'Pendidikan' : 'Pengalaman'} berhasil ditambahkan',
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Return to previous screen with success indicator
      Navigator.pop(context, true);
    }
  }

  Widget _buildSectionHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isEducation ? Icons.school : Icons.work,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditMode
                        ? 'Edit ${isEducation ? 'Pendidikan' : 'Pengalaman'}'
                        : 'Tambah ${isEducation ? 'Pendidikan' : 'Pengalaman'}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    isEditMode
                        ? 'Perbarui informasi ${isEducation ? 'pendidikan' : 'pengalaman kerja'}'
                        : 'Tambahkan ${isEducation ? 'riwayat pendidikan' : 'pengalaman kerja'} Anda',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String title,
    required Widget child,
    String? description,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (description != null) ...[
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationForm() {
    return Column(
      children: [
        // Nama Institusi/Sekolah
        _buildFormField(
          title: 'Nama Institusi/Sekolah',
          description: 'Masukkan nama lengkap institusi pendidikan',
          child: TextFormField(
            controller: _institutionController,
            decoration: _buildModernInputDecoration(
              labelText: 'Nama Institusi',
              hintText: 'Contoh: Universitas Indonesia',
              prefixIcon: Icon(
                Icons.school_outlined,
                color: Colors.grey[600],
                size: 20,
              ),
            ),
            validator: (value) => _validateRequired(value, 'Nama institusi'),
            textCapitalization: TextCapitalization.words,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),

        // Jenjang Pendidikan
        _buildFormField(
          title: 'Jenjang Pendidikan',
          description: 'Pilih jenjang pendidikan yang sesuai',
          child: DropdownButtonFormField<String>(
            value: _degreeController.text.isEmpty
                ? null
                : _degreeController.text,
            decoration: _buildModernInputDecoration(
              labelText: 'Jenjang Pendidikan',
              prefixIcon: Icon(
                Icons.military_tech_outlined,
                color: Colors.grey[600],
                size: 20,
              ),
            ),
            items: _educationDegrees.map((String degree) {
              return DropdownMenuItem<String>(
                value: degree,
                child: Text(
                  degree,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _degreeController.text = newValue ?? '';
              });
            },
            validator: (value) =>
                _validateRequired(value, 'Jenjang pendidikan'),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey[600],
            ),
          ),
        ),

        // Jurusan/Bidang Studi
        _buildFormField(
          title: 'Jurusan/Bidang Studi',
          description: 'Masukkan jurusan atau bidang studi',
          child: TextFormField(
            controller: _fieldController,
            decoration: _buildModernInputDecoration(
              labelText: 'Jurusan/Bidang Studi',
              hintText: 'Contoh: Teknik Informatika',
              prefixIcon: Icon(
                Icons.subject_outlined,
                color: Colors.grey[600],
                size: 20,
              ),
            ),
            validator: (value) =>
                _validateRequired(value, 'Jurusan/bidang studi'),
            textCapitalization: TextCapitalization.words,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),

        // Periode Pendidikan
        Row(
          children: [
            Expanded(
              child: _buildFormField(
                title: 'Tahun Mulai',
                child: TextFormField(
                  controller: _startDateController,
                  decoration: _buildModernInputDecoration(
                    labelText: 'Tahun Mulai',
                    hintText: '2018',
                    prefixIcon: Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  readOnly: true,
                  onTap: () => _selectYear(_startDateController),
                  validator: (value) => _validateRequired(value, 'Tahun mulai'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildFormField(
                title: 'Tahun Selesai',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _endDateController,
                      decoration: _buildModernInputDecoration(
                        labelText: 'Tahun Selesai',
                        hintText: '2022',
                        prefixIcon: Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
                      readOnly: true,
                      enabled: !_isCurrentlyStudying,
                      onTap: _isCurrentlyStudying
                          ? null
                          : () => _selectYear(_endDateController),
                      validator: _isCurrentlyStudying
                          ? null
                          : (value) =>
                                _validateRequired(value, 'Tahun selesai'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _isCurrentlyStudying,
                          onChanged: (bool? value) {
                            setState(() {
                              _isCurrentlyStudying = value ?? false;
                              if (_isCurrentlyStudying) {
                                _endDateController.clear();
                              }
                            });
                          },
                          activeColor: Color(0xFF007AFF),
                        ),
                        Expanded(
                          child: Text(
                            'Sedang bersekolah/kuliah',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // IPK/Nilai (Opsional)
        _buildFormField(
          title: 'IPK/Nilai (Opsional)',
          description: 'Masukkan IPK atau nilai rata-rata (skala 4.0)',
          child: TextFormField(
            controller: _gradeController,
            decoration: _buildModernInputDecoration(
              labelText: 'IPK/Nilai',
              hintText: '3.75',
              prefixIcon: Icon(
                Icons.grade_outlined,
                color: Colors.grey[600],
                size: 20,
              ),
            ),
            validator: _validateGrade,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceForm() {
    return Column(
      children: [
        // Nama Perusahaan
        _buildFormField(
          title: 'Nama Perusahaan',
          description: 'Masukkan nama lengkap perusahaan',
          child: TextFormField(
            controller: _companyController,
            decoration: _buildModernInputDecoration(
              labelText: 'Nama Perusahaan',
              hintText: 'Contoh: PT. Teknologi Digital Indonesia',
              prefixIcon: Icon(
                Icons.business_outlined,
                color: Colors.grey[600],
                size: 20,
              ),
            ),
            validator: (value) => _validateRequired(value, 'Nama perusahaan'),
            textCapitalization: TextCapitalization.words,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),

        // Posisi/Jabatan
        _buildFormField(
          title: 'Posisi/Jabatan',
          description: 'Masukkan posisi atau jabatan dalam perusahaan',
          child: TextFormField(
            controller: _positionController,
            decoration: _buildModernInputDecoration(
              labelText: 'Posisi/Jabatan',
              hintText: 'Contoh: Mobile Developer',
              prefixIcon: Icon(
                Icons.work_outline,
                color: Colors.grey[600],
                size: 20,
              ),
            ),
            validator: (value) => _validateRequired(value, 'Posisi/jabatan'),
            textCapitalization: TextCapitalization.words,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),

        // Periode Kerja
        Row(
          children: [
            Expanded(
              child: _buildFormField(
                title: 'Mulai Kerja',
                child: TextFormField(
                  controller: _startDateController,
                  decoration: _buildModernInputDecoration(
                    labelText: 'Mulai Kerja',
                    hintText: 'Jan 2023',
                    prefixIcon: Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  readOnly: true,
                  onTap: () => _selectMonthYear(_startDateController),
                  validator: (value) =>
                      _validateRequired(value, 'Tanggal mulai kerja'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildFormField(
                title: 'Selesai Kerja',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _endDateController,
                      decoration: _buildModernInputDecoration(
                        labelText: 'Selesai Kerja',
                        hintText: 'Des 2023',
                        prefixIcon: Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
                      readOnly: true,
                      enabled: !_isCurrentlyWorking,
                      onTap: _isCurrentlyWorking
                          ? null
                          : () => _selectMonthYear(_endDateController),
                      validator: _isCurrentlyWorking
                          ? null
                          : (value) => _validateRequired(
                              value,
                              'Tanggal selesai kerja',
                            ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _isCurrentlyWorking,
                          onChanged: (bool? value) {
                            setState(() {
                              _isCurrentlyWorking = value ?? false;
                              if (_isCurrentlyWorking) {
                                _endDateController.clear();
                              }
                            });
                          },
                          activeColor: Color(0xFF007AFF),
                        ),
                        Expanded(
                          child: Text(
                            'Masih bekerja di sini',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Deskripsi Pekerjaan (Opsional)
        _buildFormField(
          title: 'Deskripsi Pekerjaan (Opsional)',
          description: 'Jelaskan tanggung jawab dan pencapaian Anda',
          child: TextFormField(
            controller: _descriptionController,
            decoration: _buildModernInputDecoration(
              labelText: 'Deskripsi Pekerjaan',
              hintText:
                  'Contoh: Mengembangkan aplikasi mobile menggunakan Flutter...',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.description_outlined,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ),
            ),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          isEditMode
              ? 'Edit ${isEducation ? 'Pendidikan' : 'Pengalaman'}'
              : 'Tambah ${isEducation ? 'Pendidikan' : 'Pengalaman'}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.black87,
              size: 18,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildSectionHeader(),

                // Form Fields
                if (isEducation)
                  _buildEducationForm()
                else
                  _buildExperienceForm(),

                SizedBox(height: 8),

                // Save Button
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: _isLoading
                          ? null
                          : LinearGradient(
                              colors: [
                                const Color(0xFF007AFF),
                                const Color(0xFF5856D6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _isLoading ? Colors.grey[300] : null,
                      boxShadow: _isLoading
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFF007AFF).withOpacity(0.3),
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.grey[600]!,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Menyimpan...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_outlined, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  isEditMode
                                      ? 'Simpan Perubahan'
                                      : 'Simpan ${isEducation ? 'Pendidikan' : 'Pengalaman'}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Info Tips
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[600],
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Tips Penting',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          isEducation
                              ? '• Pastikan nama institusi dan jurusan sesuai dengan ijazah\n'
                                    '• IPK/nilai boleh dikosongkan jika tidak ingin ditampilkan\n'
                                    '• Centang "sedang bersekolah/kuliah" jika masih aktif\n'
                                    '• Informasi ini akan digunakan untuk keperluan administrasi'
                              : '• Gunakan nama perusahaan yang resmi dan lengkap\n'
                                    '• Jelaskan tanggung jawab dan pencapaian dengan detail\n'
                                    '• Centang "masih bekerja di sini" jika masih aktif\n'
                                    '• Update informasi jika ada perubahan status pekerjaan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

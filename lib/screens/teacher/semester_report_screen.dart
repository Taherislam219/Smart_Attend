import '../../theme/smartattend_theme.dart';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Teacher-only semester register. The RPC, not Flutter, checks class ownership.
class SemesterReportScreen extends StatefulWidget {
  final Map<String, dynamic> classData;
  const SemesterReportScreen({super.key, required this.classData});

  @override
  State<SemesterReportScreen> createState() => _SemesterReportScreenState();
}

class _SemesterReportScreenState extends State<SemesterReportScreen> {
  static Color get bg => SmartAttendPalette.background;
  static Color get ink => SmartAttendPalette.text;
  static Color get muted => SmartAttendPalette.muted;
  static Color get shadow => SmartAttendPalette.shadow;

  bool loading = true;
  bool exporting = false;
  String? error;
  String search = '';
  bool lowOnly = false;
  double lowThreshold = 75;
  List<Map<String, dynamic>> rows = [];
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await Supabase.instance.client.rpc(
        'teacher_semester_attendance',
        params: {'p_class_id': widget.classData['id'].toString()},
      );
      if (!mounted) return;
      setState(() => rows = List<Map<String, dynamic>>.from(data as List));
    } on PostgrestException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not load semester report: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String bdt(Object? value) {
    final time = DateTime.tryParse(value?.toString() ?? '');
    if (time == null) return '—';
    final local = time.toUtc().add(Duration(hours: 6));
    return '${local.day}/${local.month}/${local.year}';
  }

  Map<String, dynamic> assemble() {
    final lectureMap = <String, Map<String, dynamic>>{};
    final studentMap = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = row['student_id'].toString();
      studentMap.putIfAbsent(
        id,
        () => {
          'name': row['full_name']?.toString() ?? '',
          'studentId': row['university_student_id']?.toString() ?? '',
          'statuses': <String, String>{},
        },
      );
      if (row['sheet_id'] == null) continue;
      final sheetId = row['sheet_id'].toString();
      lectureMap.putIfAbsent(
        sheetId,
        () => {
          'id': sheetId,
          'title': row['lecture_title']?.toString() ?? 'Lecture',
          'date': bdt(row['lecture_date']),
          'sort':
              DateTime.tryParse(row['lecture_date']?.toString() ?? '')
                  ?.millisecondsSinceEpoch ??
              0,
        },
      );
      (studentMap[id]!['statuses'] as Map<String, String>)[sheetId] =
          row['attendance_status']?.toString() ?? 'NM';
    }
    final lectures = lectureMap.values.toList()
      ..sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));
    final students = studentMap.values.toList()
      ..sort(
        (a, b) =>
            a['studentId'].toString().compareTo(b['studentId'].toString()),
      );
    return {'lectures': lectures, 'students': students};
  }

  int countFor(Map<String, dynamic> student, String label) {
    final states = (student['statuses'] as Map<String, String>).values;
    return states.where((status) => status == label).length;
  }

  // Every finalized lecture counts, including NM for late enrollment.
  int countedLectures(Map<String, dynamic> student) =>
      (student['statuses'] as Map<String, String>).length;

  double? percent(Map<String, dynamic> student) {
    final total = countedLectures(student);
    if (total == 0) return null;
    return 100 * countFor(student, 'P') / total;
  }

  List<Map<String, dynamic>> filterStudents(
    List<Map<String, dynamic>> students,
  ) {
    final needle = search.trim().toLowerCase();
    return students.where((s) {
      final match =
          s['name'].toString().toLowerCase().contains(needle) ||
          s['studentId'].toString().toLowerCase().contains(needle);
      final ratio = percent(s);
      return match && (!lowOnly || (ratio != null && ratio < lowThreshold));
    }).toList();
  }

  pw.Document makePdf(
    List<Map<String, dynamic>> lectures,
    List<Map<String, dynamic>> students,
  ) {
    final pdf = pw.Document();
    final headers = [
      'Student ID',
      'Name',
      ...List.generate(lectures.length, (i) => 'L${i + 1}'),
      'P',
      'A',
      'NM',
      'Total',
      '%',
    ];
    final data = students.map((student) {
      final statuses = student['statuses'] as Map<String, String>;
      return <String>[
        student['studentId'].toString(),
        student['name'].toString(),
        ...lectures.map((lecture) => statuses[lecture['id']] ?? 'NM'),
        '${countFor(student, 'P')}',
        '${countFor(student, 'A')}',
        '${countFor(student, 'NM')}',
        '${countedLectures(student)}',
        percent(student)?.toStringAsFixed(1) ?? '—',
      ];
    }).toList();

    final title = widget.classData['course_name']?.toString() ?? 'Class';
    final code = widget.classData['course_code']?.toString() ?? '';
    final semester = widget.classData['semester']?.toString() ?? '';
    final section = widget.classData['section']?.toString() ?? '';
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.all(22),
        build: (_) => [
          pw.Text(
            'SmartAttend — Semester Attendance Register',
            style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('$title  |  $code  |  $semester  |  Section $section'),
          pw.SizedBox(height: 12),
          pw.Text(
            'P = Present, A = Absent, NM = No Mark (counts as absent). '
            'Only finalized lectures are counted.',
            style: pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          if (lectures.isEmpty)
            pw.Text('No finalized lectures yet.')
          else
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: pw.TextStyle(fontSize: 7),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: pw.EdgeInsets.all(3),
            ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Lecture key:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          ...List.generate(
            lectures.length,
            (i) => pw.Text(
              'L${i + 1}: ${lectures[i]['title']} — ${lectures[i]['date']}',
              style: pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
    return pdf;
  }

  Future<void> exportPdf(
    List<Map<String, dynamic>> lectures,
    List<Map<String, dynamic>> students,
  ) async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      final pdf = makePdf(lectures, students);
      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'SmartAttend_Semester_Report.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Widget card(Widget child) => Container(
    padding: EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: SmartAttendPalette.highlight,
          offset: Offset(-4, -4),
          blurRadius: 10,
        ),
        BoxShadow(color: shadow, offset: Offset(4, 4), blurRadius: 10),
      ],
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild when the app theme changes.
    final assembled = assemble();
    final lectures = assembled['lectures'] as List<Map<String, dynamic>>;
    final students = filterStudents(
      assembled['students'] as List<Map<String, dynamic>>,
    );
    final allStudents = assembled['students'] as List<Map<String, dynamic>>;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Semester Attendance'),
        backgroundColor: bg,
        foregroundColor: ink,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: reload,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1050),
          child: ListView(
            padding: EdgeInsets.all(22),
            children: [
              Text(
                widget.classData['course_name']?.toString() ?? '',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '${widget.classData['course_code']} · ${widget.classData['semester']} · '
                'Section ${widget.classData['section']}',
                style: TextStyle(color: muted),
              ),
              SizedBox(height: 24),
              if (loading)
                Center(child: CircularProgressIndicator())
              else if (error != null)
                card(
                  Column(
                    children: [
                      Text(error!),
                      TextButton(onPressed: reload, child: Text('Retry')),
                    ],
                  ),
                )
              else ...[
                Text(
                  '${allStudents.length} students  •  ${lectures.length} finalized lectures',
                  style: TextStyle(color: muted),
                ),
                SizedBox(height: 18),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search name or student ID',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) => setState(() => search = text),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: lowOnly,
                      onChanged: (value) =>
                          setState(() => lowOnly = value ?? false),
                    ),
                    Expanded(child: Text('Low attendance only')),
                    DropdownButton<double>(
                      value: lowThreshold,
                      items: [65.0, 70.0, 75.0, 80.0]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('< ${value.toInt()}%'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => lowThreshold = value ?? 75),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: exporting
                        ? null
                        : () => exportPdf(lectures, students),
                    icon: Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      exporting
                          ? 'Preparing PDF...'
                          : 'Export PDF (${students.length})',
                    ),
                  ),
                ),
                SizedBox(height: 16),
                if (lectures.isEmpty)
                  card(
                    Text(
                      'No finalized lectures yet. Finalize an open sheet '
                      'after its deadline to begin the semester register.',
                    ),
                  )
                else
                  card(
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          SmartAttendTheme.isDark
                              ? const Color(0xFF34434D)
                              : const Color(0xFFDDE6EC),
                        ),
                        headingTextStyle: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.bold,
                        ),
                        columns: [
                          DataColumn(label: Text('Student ID')),
                          DataColumn(label: Text('Student')),
                          for (var i = 0; i < lectures.length; i++)
                            DataColumn(
                              label: Tooltip(
                                message:
                                    '${lectures[i]['title']} • ${lectures[i]['date']}',
                                child: Text('L${i + 1}'),
                              ),
                            ),
                          DataColumn(label: Text('P')),
                          DataColumn(label: Text('A')),
                          DataColumn(label: Text('NM')),
                          DataColumn(label: Text('Total')),
                          DataColumn(label: Text('%')),
                        ],
                        rows: students.map((student) {
                          final statuses =
                              student['statuses'] as Map<String, String>;
                          final ratio = percent(student);
                          return DataRow(
                            cells: [
                              DataCell(Text(student['studentId'].toString())),
                              DataCell(Text(student['name'].toString())),
                              for (final lecture in lectures)
                                DataCell(Text(statuses[lecture['id']] ?? 'NM')),
                              DataCell(Text('${countFor(student, 'P')}')),
                              DataCell(Text('${countFor(student, 'A')}')),
                              DataCell(Text("${countFor(student, 'NM')}")),
                              DataCell(Text('${countedLectures(student)}')),
                              DataCell(
                                Text(
                                  ratio == null
                                      ? '—'
                                      : '${ratio.toStringAsFixed(1)}%',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                SizedBox(height: 18),
                Text(
                  'P = Present · A = Absent · NM = No Mark (counts as absent). '
                  'Only finalized lectures affect percentages.',
                  style: TextStyle(color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

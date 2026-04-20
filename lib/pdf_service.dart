import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PdfService {
  static Future<void> exportLogbook() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    // Ambil data profil
    final profilDoc = await db.collection('users').doc(uid).get();
    final profil = profilDoc.data() ?? {};

    // Ambil data logbook
    final logbookSnapshot = await db
        .collection('users')
        .doc(uid)
        .collection('logbook')
        .orderBy('timestamp', descending: false)
        .get();

    // Ambil data absensi
    final absensiSnapshot = await db
        .collection('users')
        .doc(uid)
        .collection('absensi')
        .orderBy('timestamp', descending: false)
        .get();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Center(
            child: pw.Text(
              'LAPORAN MAGANG',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'InJourney Airport',
              style: pw.TextStyle(fontSize: 14),
            ),
          ),
          pw.Divider(),
          pw.SizedBox(height: 12),

          // Data Diri
          pw.Text(
            'DATA DIRI',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            children: [
              _tableRow('Nama', profil['nama'] ?? '-'),
              _tableRow('NIM', profil['nim'] ?? '-'),
              _tableRow('Program Studi', profil['prodi'] ?? '-'),
              _tableRow('Universitas', profil['universitas'] ?? '-'),
              _tableRow('Email', profil['email'] ?? '-'),
              _tableRow('No. HP', profil['noHp'] ?? '-'),
            ],
          ),
          pw.SizedBox(height: 20),

          // Rekap Absensi
          pw.Text(
            'REKAP ABSENSI',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['No', 'Tanggal', 'Status'],
            data: absensiSnapshot.docs.asMap().entries.map((e) {
              final data = e.value.data();
              return [
                '${e.key + 1}',
                data['tanggal'] ?? '-',
                data['status'] ?? '-',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey100,
            ),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 20),

          // Logbook
          pw.Text(
            'LOGBOOK HARIAN',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['No', 'Tanggal', 'Kegiatan'],
            data: logbookSnapshot.docs.asMap().entries.map((e) {
              final data = e.value.data();
              return [
                '${e.key + 1}',
                data['tanggal'] ?? '-',
                data['kegiatan'] ?? '-',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey100,
            ),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  static pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(value),
        ),
      ],
    );
  }
}
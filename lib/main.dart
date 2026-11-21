import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  runApp(const QrPdfApp());
}

class QrPdfApp extends StatelessWidget {
  const QrPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Генератор QR-кодов в PDF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Arial',
      ),
      home: const QrGeneratorPage(),
    );
  }
}

class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({super.key});

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  final TextEditingController _textController = TextEditingController();
  List<String> _qrItems = [];
  bool _isGeneratingPdf = false;
  bool _gridMode = false;

  void _generateQrCodes() {
    final lines = _textController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    setState(() {
      _qrItems = lines;
    });
  }

  void _removeQrItem(int index) {
    setState(() {
      _qrItems.removeAt(index);
    });
  }

  Future<void> _saveToPdf() async {
    if (_qrItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала сгенерируйте хотя бы один QR-код')),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await _buildPdfDocument(_qrItems, gridMode: _gridMode);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'qrcodes.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при создании PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<Uint8List> _buildPdfDocument(List<String> items, {required bool gridMode}) async {
    final pdf = pw.Document();
    final fontBold = await PdfGoogleFonts.robotoBold();

    if (!gridMode) {
      for (final text in items) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: text,
                      width: 280,
                      height: 280,
                    ),
                    pw.SizedBox(height: 24),
                    pw.Text(
                      text,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    } else {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Wrap(
                spacing: 24,
                runSpacing: 24,
                children: items.map((text) {
                  return pw.SizedBox(
                    width: 155,
                    child: pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: text,
                          width: 130,
                          height: 130,
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          text,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ];
          },
        ),
      );
    }

    return pdf.save();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Генератор QR-кодов в PDF',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 340,
                    child: TextField(
                      controller: _textController,
                      maxLines: 5,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Введите текст или URL (каждый в новой строке)',
                        hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFE9EFF6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _gridMode,
                        activeColor: const Color(0xFF008CBA),
                        onChanged: (val) {
                          setState(() {
                            _gridMode = val ?? false;
                          });
                        },
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _gridMode = !_gridMode),
                        child: const Text(
                          'Сеткой на листе A4 (несколько на страницу)',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildActionButton(
                        label: 'Сгенерировать QR-коды',
                        onPressed: _generateQrCodes,
                      ),
                      _buildActionButton(
                        label: _isGeneratingPdf ? 'Создание PDF...' : 'Сохранить в PDF',
                        onPressed: _isGeneratingPdf ? null : _saveToPdf,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: List.generate(_qrItems.length, (index) {
                      final itemText = _qrItems[index];
                      return SizedBox(
                        width: 220,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            QrImageView(
                              data: itemText,
                              version: QrVersions.auto,
                              size: 200.0,
                              backgroundColor: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              itemText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _removeQrItem(index),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                child: Text(
                                  'Удалить',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 240,
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF008CBA),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

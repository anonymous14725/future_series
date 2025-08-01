import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';

class PdfViewerPage extends StatelessWidget {
  final String filePath;
  final String? fileName;

  const PdfViewerPage({Key? key, required this.filePath, this.fileName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName ?? 'PDF Document'),
      ),
      body: SfPdfViewer.file(
        File(filePath),
        canShowScrollHead: true,
        canShowScrollStatus: true,
      ),
    );
  }
}
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/record_model.dart';

class PanchanamaPdfService {
  static Future<void> export(LocalRecordModel record, {File? evidencePhoto}) async {
    final document = pw.Document();
    pw.Widget footer(pw.Context context) => pw.Column(
      children: [
        pw.Divider(),
        pw.Text(
          'STATUTORY WARNING: Presumptive field result only. Confirmatory laboratory examination is mandatory. '
          'This document contains sensitive evidence and must be handled under departmental procedure.',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Page ${context.pageNumber} of 6 • Generated on-device • BSA §63 integrity record',
            style: const pw.TextStyle(fontSize: 7)),
      ],
    );
    pw.Widget heading(String title, String subtitle) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('MINISTRY OF HOME AFFAIRS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text('FIELD DRUG TESTING COMPANION • NDPS §52A', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 18),
        pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text(subtitle, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
      ],
    );
    pw.Widget row(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 150, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
          pw.Expanded(child: pw.Text(value.isEmpty ? 'NOT RECORDED' : value, style: const pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
    pw.Page page(pw.Widget body) => pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 40, 42, 32),
      footer: footer,
      build: (_) => body,
    );

    document.addPage(page(pw.Column(children: [
      heading('PANCHANAMA / DIGITAL EVIDENCE DOSSIER', '1. Case identification and statutory declaration'),
      row('Test reference', record.testId),
      row('FIR / Crime number', record.firNumber),
      row('Officer / badge', record.officerId),
      row('Device identifier', record.deviceId),
      row('Recorded at', record.formattedDate),
      row('Result classification', record.classification),
      row('Legal status', 'Presumptive field result; laboratory confirmation required'),
    ])));
    document.addPage(page(pw.Column(children: [
      heading('SEIZURE AND PANCH WITNESS RECORD', '2. Scene, persons and sample particulars'),
      row('Exact seizure location', record.seizureLocation),
      row('Panch witness details', record.panchWitnessDetails),
      row('Accused / suspect present', record.accusedPresent ? 'YES' : 'NO'),
      row('Substance description', record.substanceDescription),
      row('Packaging markings', record.packagingMarkings),
      row('Seal serial', record.sealSerial),
    ])));
    document.addPage(page(pw.Column(children: [
      heading('MEASUREMENT AND OPTICAL ANALYSIS', '3. Instrument output retained with the record'),
      row('Kit / assay', record.kitType),
      row('Card serial', record.cardSerial),
      row('Gross weight', record.grossWeight),
      row('Net sample weight', record.netWeight),
      row('CIEDE2000 delta E', record.deltaE2000.toStringAsFixed(2)),
      row('Confidence', '${record.confidence.toStringAsFixed(1)}%'),
      row('Reaction window', '${record.reactionTimeSeconds} seconds'),
      row('Evidence image SHA-256', record.imageSha256),
    ])));
    document.addPage(page(pw.Column(children: [
      heading('LOCATION AND CHAIN OF CUSTODY', '4. Capture provenance'),
      row('Location status', record.locationStatus),
      row('Latitude', record.latitude?.toStringAsFixed(6) ?? 'UNCONFIRMED'),
      row('Longitude', record.longitude?.toStringAsFixed(6) ?? 'UNCONFIRMED'),
      row('Previous block hash', record.prevHash),
      row('Current block hash', record.recordHash),
      if (evidencePhoto != null && evidencePhoto.existsSync())
        pw.Container(
          height: 280,
          width: double.infinity,
          alignment: pw.Alignment.center,
          child: pw.Image(pw.MemoryImage(evidencePhoto.readAsBytesSync()), fit: pw.BoxFit.contain),
        ),
    ])));
    document.addPage(page(pw.Column(children: [
      heading('DIGITAL SIGNATURE CERTIFICATE', '5. BSA §63 electronic record statement'),
      row('Device signature (P-256)', record.deviceSigHex),
      row('Officer signature', record.officerSigHex),
      row('Supervisor co-signature', record.supervisorSigHex ?? 'NOT REQUIRED / PENDING'),
      row('Supervisor identity', record.supervisorId ?? 'NOT APPLIED'),
      row('Dual-sign state', record.deviceSigHex.isNotEmpty && record.officerSigHex.isNotEmpty ? 'SEALED' : 'INVALID'),
      pw.SizedBox(height: 12),
      pw.Text(
        'The signer records above are bound to the canonical record payload and its preceding hash link. '
        'Any alteration changes the digest and must be treated as a chain-integrity failure.',
        style: const pw.TextStyle(fontSize: 10),
      ),
    ])));
    document.addPage(page(pw.Column(children: [
      heading('INTEGRITY CERTIFICATE AND ACKNOWLEDGEMENT', '6. Final review and handling instructions'),
      row('Record hash', record.recordHash),
      row('Previous hash', record.prevHash),
      row('SMS witness state', record.isSmsWitnessed == 1 ? 'DISPATCHED / RECORDED' : 'PENDING OR UNCONFIRMED'),
      row('Metadata sync state', record.isStage1Synced == 1 ? 'UPLOADED' : 'OFFLINE / PENDING'),
      pw.SizedBox(height: 18),
      pw.Text('Officer acknowledgement: ________________________________', style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 20),
      pw.Text('Supervisor acknowledgement: _____________________________', style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 22),
      pw.Text(
        'This export is generated from the encrypted on-device evidence ledger. Preserve the original device, '
        'the source image, and the signature verification material with the case file.',
        style: const pw.TextStyle(fontSize: 10),
      ),
    ])));

    await Printing.sharePdf(
      bytes: await document.save(),
      filename: '${record.testId}_Panchanama_BSA63.pdf',
    );
  }
}
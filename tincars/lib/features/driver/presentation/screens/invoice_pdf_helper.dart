import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';

class InvoicePdfHelper {
  static Future<void> generateAndPrintInvoice(Trip trip) async {
    final pdf = pw.Document();

    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'es').format(trip.createdAt);
    final timeStr = DateFormat('hh:mm a').format(trip.createdAt);
    final total = trip.price;
    final driverEarning = total * 0.8;
    final appFee = total * 0.2;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TINCARS',
                            style: pw.TextStyle(
                                fontSize: 32, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Comprobante de Viaje',
                            style: const pw.TextStyle(fontSize: 16)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('ID: #${trip.id.substring(0, 8).toUpperCase()}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(dateStr),
                        pw.Text(timeStr),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 40),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // Route Info
                pw.Text('DETALLES DE LA RUTA',
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                _buildPdfLocationRow('Origen', trip.pickupAddress),
                pw.SizedBox(height: 10),
                if (trip.intermediateStops.isNotEmpty)
                  ...trip.intermediateStops.map((s) => pw.Column(children: [
                        _buildPdfLocationRow('Parada', s.address),
                        pw.SizedBox(height: 10),
                      ])),
                _buildPdfLocationRow('Destino', trip.dropoffAddress),

                pw.SizedBox(height: 40),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // Financial Info
                pw.Text('RESUMEN FINANCIERO',
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                _buildPdfReceiptRow('Tarifa del viaje', '\$${total.toStringAsFixed(0)}'),
                if (trip.tipAmount != null && trip.tipAmount! > 0)
                  _buildPdfReceiptRow(
                      'Propina', '\$${trip.tipAmount!.toStringAsFixed(0)}'),
                pw.SizedBox(height: 10),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 10),
                _buildPdfReceiptRow(
                    'Ganancia Conductor (80%)', '\$${driverEarning.toStringAsFixed(0)}',
                    isBold: true),
                _buildPdfReceiptRow(
                    'Tasa de Servicio (20%)', '\$${appFee.toStringAsFixed(0)}'),

                pw.SizedBox(height: 40),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // Payment Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Método de Pago:'),
                    pw.Text(trip.paymentMethod,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),

                pw.Spacer(),
                pw.Center(
                  child: pw.Text('Gracias por viajar con Tincars',
                      style: pw.TextStyle(
                          color: PdfColors.grey, fontStyle: pw.FontStyle.italic)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildPdfLocationRow(String label, String address) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(address, style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  static pw.Widget _buildPdfReceiptRow(String label, String value,
      {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
          pw.Text(value,
              style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
        ],
      ),
    );
  }
}

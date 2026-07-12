import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/booking_model.dart';
import '../../models/customer_model.dart';
import '../../models/lead_model.dart';
import '../../models/plot_model.dart';
import '../../models/site_model.dart';

class ReportExportData {
  const ReportExportData({
    required this.leads,
    required this.customers,
    required this.plots,
    required this.bookings,
    required this.sites,
  });

  final List<LeadModel> leads;
  final List<CustomerModel> customers;
  final List<PlotModel> plots;
  final List<BookingModel> bookings;
  final List<SiteModel> sites;
}

/// Generates downloadable reports entirely on the device/browser.
class ReportExportService {
  ReportExportService._();

  static final ReportExportService instance = ReportExportService._();
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  Future<void> exportCsv(ReportExportData data) async {
    final rows = <List<dynamic>>[
      ['PlottingBazaar CRM report', _dateFormat.format(DateTime.now())],
      [],
      ['Summary', 'Value'],
      ..._summaryRows(data),
      [],
      ['Leads'],
      ['Name', 'Phone', 'Site', 'Status', 'Follow-up date', 'Created'],
      ...data.leads.map(
        (lead) => [
          lead.name,
          lead.phone,
          lead.site,
          lead.status,
          _date(lead.followUpDate),
          _date(lead.createdAt),
        ],
      ),
      [],
      ['Customers'],
      ['Name', 'Mobile', 'Email', 'Address', 'Status', 'Created'],
      ...data.customers.map(
        (customer) => [
          customer.name,
          customer.mobile,
          customer.email ?? '',
          customer.address ?? '',
          customer.isActive ? 'Active' : 'Inactive',
          _date(customer.createdAt),
        ],
      ),
      [],
      ['Plots'],
      ['Plot', 'Block', 'Site', 'Area', 'Rate', 'Value', 'Status'],
      ...data.plots.map(
        (plot) => [
          plot.plotNo,
          plot.block,
          _siteName(data, plot.siteId),
          plot.area.toStringAsFixed(2),
          plot.rate.toStringAsFixed(2),
          plot.totalPrice.toStringAsFixed(2),
          plot.status,
        ],
      ),
      [],
      ['Bookings'],
      [
        'Customer',
        'Plot',
        'Site',
        'Booking date',
        'Sale price',
        'Booking amount',
        'Discount',
        'Balance',
        'Status',
      ],
      ...data.bookings.map(
        (booking) => [
          _customerName(data, booking.customerId),
          _plotName(data, booking.plotId),
          _siteName(data, booking.siteId),
          _date(booking.bookingDate),
          booking.salePrice.toStringAsFixed(2),
          booking.bookingAmount.toStringAsFixed(2),
          booking.discount.toStringAsFixed(2),
          booking.balance.toStringAsFixed(2),
          booking.status,
        ],
      ),
    ];

    final csv = const CsvEncoder(addBom: true).convert(rows);
    await FileSaver.instance.saveFile(
      name: _fileName('report'),
      bytes: Uint8List.fromList(utf8.encode(csv)),
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
  }

  Future<void> exportPdf(ReportExportData data) async {
    final document = pw.Document();
    final dueLeads =
        data.leads.where((lead) => lead.followUpDate != null).toList()
          ..sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'PlottingBazaar CRM Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Generated on ${_dateFormat.format(DateTime.now())}'),
          pw.SizedBox(height: 18),
          pw.Text(
            'Business summary',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            context: context,
            headers: const ['Metric', 'Value'],
            data: _summaryRows(data),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey100,
            ),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Follow-up list',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (dueLeads.isEmpty)
            pw.Text('No follow-ups are scheduled.')
          else
            pw.TableHelper.fromTextArray(
              context: context,
              headers: const ['Date', 'Lead', 'Phone', 'Site', 'Status'],
              data: dueLeads
                  .map(
                    (lead) => [
                      _date(lead.followUpDate),
                      lead.name,
                      lead.phone,
                      lead.site,
                      lead.status,
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey100,
              ),
              cellAlignment: pw.Alignment.centerLeft,
            ),
        ],
      ),
    );

    await FileSaver.instance.saveFile(
      name: _fileName('report'),
      bytes: await document.save(),
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  List<List<String>> _summaryRows(ReportExportData data) {
    final availablePlots = data.plots
        .where((plot) => plot.status.toLowerCase() == 'available')
        .length;
    final followUps = data.leads
        .where((lead) => lead.followUpDate != null)
        .length;
    final saleValue = data.bookings.fold<double>(
      0,
      (total, booking) => total + booking.salePrice,
    );
    final collected = data.bookings.fold<double>(
      0,
      (total, booking) => total + booking.bookingAmount,
    );
    final balance = data.bookings.fold<double>(
      0,
      (total, booking) => total + booking.balance,
    );

    return [
      ['Total leads', '${data.leads.length}'],
      ['Leads with follow-up', '$followUps'],
      ['Customers', '${data.customers.length}'],
      ['Active sites', '${data.sites.where((site) => site.isActive).length}'],
      ['Available plots', '$availablePlots of ${data.plots.length}'],
      ['Bookings', '${data.bookings.length}'],
      ['Sales value', _money.format(saleValue)],
      ['Amount collected', _money.format(collected)],
      ['Outstanding balance', _money.format(balance)],
    ];
  }

  String _fileName(String kind) =>
      'plottingbazaar_${kind}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';

  String _date(DateTime? value) =>
      value == null ? '' : _dateFormat.format(value.toLocal());

  String _siteName(ReportExportData data, String siteId) =>
      data.sites
          .where((site) => site.id == siteId)
          .map((site) => site.name)
          .firstOrNull ??
      siteId;

  String _customerName(ReportExportData data, String customerId) =>
      data.customers
          .where((customer) => customer.id == customerId)
          .map((customer) => customer.name)
          .firstOrNull ??
      customerId;

  String _plotName(ReportExportData data, String plotId) =>
      data.plots
          .where((plot) => plot.id == plotId)
          .map((plot) => '${plot.block} - ${plot.plotNo}')
          .firstOrNull ??
      plotId;
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/report_export_service.dart';
import '../../models/lead_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/plot_provider.dart';
import '../../providers/site_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  static final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAll);
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([
        ref.read(leadProvider.notifier).loadLeads(),
        ref.read(customerProvider.notifier).loadCustomers(),
        ref.read(plotProvider.notifier).loadPlots(),
        ref.read(bookingProvider.notifier).loadBookings(),
        ref.read(siteProvider.notifier).loadSites(),
      ]);
    } catch (_) {
      _error = 'Some report data could not be loaded. Pull down to try again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ReportExportData get _reportData => ReportExportData(
    leads: ref.read(leadProvider),
    customers: ref.read(customerProvider),
    plots: ref.read(plotProvider),
    bookings: ref.read(bookingProvider),
    sites: ref.read(siteProvider),
  );

  Future<void> _export({required bool pdf}) async {
    setState(() => _exporting = true);

    try {
      if (pdf) {
        await ReportExportService.instance.exportPdf(_reportData);
      } else {
        await ReportExportService.instance.exportCsv(_reportData);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pdf ? 'PDF report is ready.' : 'CSV report is ready.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export the report.')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadProvider);
    final customers = ref.watch(customerProvider);
    final plots = ref.watch(plotProvider);
    final bookings = ref.watch(bookingProvider);
    final sites = ref.watch(siteProvider);

    final availablePlots = plots
        .where((plot) => plot.status.toLowerCase() == 'available')
        .length;
    final followUps = leads.where((lead) => lead.followUpDate != null).length;
    final saleValue = bookings.fold<double>(
      0,
      (total, booking) => total + booking.salePrice,
    );
    final collected = bookings.fold<double>(
      0,
      (total, booking) => total + booking.bookingAmount,
    );
    final outstanding = bookings.fold<double>(
      0,
      (total, booking) => total + booking.balance,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Exports')),
      body:
          _loading &&
              leads.isEmpty &&
              customers.isEmpty &&
              plots.isEmpty &&
              bookings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    _messageCard(_error!),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Business snapshot',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live figures from your CRM data',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth >= 700
                          ? (constraints.maxWidth - 24) / 3
                          : constraints.maxWidth >= 460
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _metricCard(
                            width: cardWidth,
                            label: 'Total leads',
                            value: '${leads.length}',
                            icon: Icons.people_outline,
                            color: Colors.blue,
                          ),
                          _metricCard(
                            width: cardWidth,
                            label: 'Follow-ups',
                            value: '$followUps',
                            icon: Icons.event_note_outlined,
                            color: Colors.orange,
                          ),
                          _metricCard(
                            width: cardWidth,
                            label: 'Customers',
                            value: '${customers.length}',
                            icon: Icons.person_outline,
                            color: Colors.teal,
                          ),
                          _metricCard(
                            width: cardWidth,
                            label: 'Available plots',
                            value: '$availablePlots / ${plots.length}',
                            icon: Icons.grid_view_rounded,
                            color: Colors.green,
                          ),
                          _metricCard(
                            width: cardWidth,
                            label: 'Sales value',
                            value: _money.format(saleValue),
                            icon: Icons.trending_up,
                            color: Colors.indigo,
                          ),
                          _metricCard(
                            width: cardWidth,
                            label: 'Collected',
                            value: _money.format(collected),
                            icon: Icons.account_balance_wallet_outlined,
                            color: Colors.purple,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lead pipeline',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          ..._pipelineRows(leads),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_city_outlined),
                      title: const Text('Active sites'),
                      subtitle: Text(
                        '${sites.where((site) => site.isActive).length} of ${sites.length} sites active',
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: const Text('Outstanding balance'),
                      trailing: Text(
                        _money.format(outstanding),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Export full report',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Includes summary, leads, customers, plots and bookings.',
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 360;
                      final csvButton = OutlinedButton.icon(
                        onPressed: _exporting
                            ? null
                            : () => _export(pdf: false),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Export CSV'),
                      );
                      final pdfButton = FilledButton.icon(
                        onPressed: _exporting ? null : () => _export(pdf: true),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(_exporting ? 'Exporting...' : 'Export PDF'),
                      );
                      return compact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                csvButton,
                                const SizedBox(height: 10),
                                pdfButton,
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: csvButton),
                                const SizedBox(width: 12),
                                Expanded(child: pdfButton),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _metricCard({
    required double width,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _pipelineRows(List<LeadModel> leads) {
    const statuses = ['New', 'Follow-up', 'Qualified', 'Booked', 'Lost'];
    final maximum = math.max(1, leads.length);

    return statuses.map((status) {
      final count = leads.where((lead) => lead.status == status).length;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SizedBox(width: 78, child: Text(status)),
            Expanded(child: LinearProgressIndicator(value: count / maximum)),
            const SizedBox(width: 12),
            Text('$count'),
          ],
        ),
      );
    }).toList();
  }

  Widget _messageCard(String message) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
  );
}

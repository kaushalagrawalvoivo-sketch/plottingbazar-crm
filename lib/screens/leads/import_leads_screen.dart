import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';

class ImportLeadsScreen extends ConsumerStatefulWidget {
  const ImportLeadsScreen({super.key});
  @override
  ConsumerState<ImportLeadsScreen> createState() => _ImportLeadsScreenState();
}

class _ImportLeadsScreenState extends ConsumerState<ImportLeadsScreen> {
  List<LeadModel> _leads = [];
  bool _saving = false;
  Future<void> _pick() async {
    final file = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (file == null || file.files.single.bytes == null) return;
    try {
      final rows = CsvToListConverter(shouldParseNumbers: false).convert(utf8.decode(file.files.single.bytes!));
      final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      String value(List row, String key) { final index = headers.indexOf(key); return index < 0 || index >= row.length ? '' : row[index].toString().trim(); }
      if (!headers.contains('name') || !headers.contains('phone') || !headers.contains('site')) throw const FormatException('CSV requires name, phone and site columns.');
      setState(() => _leads = rows.skip(1).where((row) => value(row, 'name').isNotEmpty).map((row) => LeadModel(name: value(row, 'name'), phone: value(row, 'phone'), site: value(row, 'site'), status: value(row, 'status').isEmpty ? 'New' : value(row, 'status'), assignedTo: value(row, 'assigned_to').isEmpty ? null : value(row, 'assigned_to'), followUpDate: DateTime.tryParse(value(row, 'follow_up_date')))).toList());
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
  Future<void> _import() async { setState(() => _saving = true); try { await ref.read(leadProvider.notifier).importLeads(_leads); if (mounted) Navigator.pop(context); } finally { if (mounted) setState(() => _saving = false); } }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Import leads')), body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('CSV columns: name, phone, site. Optional: status, follow_up_date, assigned_to.'), const SizedBox(height: 16), OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.upload_file), label: const Text('Choose CSV')), const SizedBox(height: 16), Text('${_leads.length} leads ready'), const Spacer(), FilledButton(onPressed: _leads.isEmpty || _saving ? null : _import, child: Text(_saving ? 'Importing...' : 'Import leads'))])));
}

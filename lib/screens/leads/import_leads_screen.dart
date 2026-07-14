import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';

class ImportLeadsScreen extends ConsumerStatefulWidget {
  const ImportLeadsScreen({super.key});
  @override ConsumerState<ImportLeadsScreen> createState() => _ImportLeadsScreenState();
}

class _ImportLeadsScreenState extends ConsumerState<ImportLeadsScreen> {
  List<LeadModel> _rows = [];
  String? _error;
  bool _saving = false;

  Future<void> _chooseFile() async {
    final selection = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (selection == null || selection.files.single.bytes == null) return;
    try {
      final table = const CsvToListConverter(shouldParseNumbers: false).convert(utf8.decode(selection.files.single.bytes!));
      if (table.length < 2) throw const FormatException('CSV has no lead rows.');
      final headers = table.first.map((value) => value.toString().trim().toLowerCase()).toList();
      String value(List<dynamic> row, String column) { final index = headers.indexOf(column); return index < 0 || index >= row.length ? '' : row[index].toString().trim(); }
      for (final required in ['name', 'phone', 'site']) { if (!headers.contains(required)) throw FormatException('Missing required column: $required'); }
      final leads = <LeadModel>[];
      for (final row in table.skip(1)) {
        final name = value(row, 'name');
        if (name.isEmpty) continue;
        leads.add(LeadModel(name: name, phone: value(row, 'phone'), site: value(row, 'site'), status: value(row, 'status').isEmpty ? 'New' : value(row, 'status'), assignedTo: value(row, 'assigned_to').isEmpty ? null : value(row, 'assigned_to'), followUpDate: DateTime.tryParse(value(row, 'follow_up_date'))));
      }
      setState(() { _rows = leads; _error = null; });
    } catch (e) { setState(() { _rows = []; _error = e.toString().replaceFirst('FormatException: ', ''); }); }
  }

  Future<void> _import() async {
    setState(() => _saving = true);
    try {
      await ref.read(leadProvider.notifier).importLeads(_rows);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_rows.length} leads imported.'))); Navigator.pop(context); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'))); }
    if (mounted) setState(() => _saving = false);
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Import leads')),
    body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Upload a CSV', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8), const Text('Required columns: name, phone, site. Optional: status, follow_up_date, assigned_to.'),
      const SizedBox(height: 20), OutlinedButton.icon(onPressed: _chooseFile, icon: const Icon(Icons.upload_file_outlined), label: const Text('Choose CSV file')),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      if (_rows.isNotEmpty) ...[const SizedBox(height: 20), Text('${_rows.length} leads ready to import', style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 10), Expanded(child: ListView.builder(itemCount: _rows.length, itemBuilder: (_, i) => ListTile(title: Text(_rows[i].name), subtitle: Text('${_rows[i].phone} · ${_rows[i].site}')))), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _import, icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload_outlined), label: const Text('Import leads')))],
    ])),
  );
}

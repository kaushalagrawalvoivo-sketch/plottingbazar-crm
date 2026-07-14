import 'dart:convert';
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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    try {
      final lines = const LineSplitter().convert(utf8.decode(result.files.single.bytes!)).where((line) => line.trim().isNotEmpty).toList();
      if (lines.length < 2) throw const FormatException('CSV has no lead rows.');
      final headers = lines.first.split(',').map((cell) => cell.trim().toLowerCase()).toList();
      String cell(List<String> row, String name) { final index = headers.indexOf(name); return index < 0 || index >= row.length ? '' : row[index].trim(); }
      if (!headers.contains('name') || !headers.contains('phone') || !headers.contains('site')) throw const FormatException('Required columns: name, phone, site.');
      final parsed = <LeadModel>[];
      for (final line in lines.skip(1)) {
        final row = line.split(',');
        final name = cell(row, 'name');
        if (name.isEmpty) continue;
        parsed.add(LeadModel(name: name, phone: cell(row, 'phone'), site: cell(row, 'site'), status: cell(row, 'status').isEmpty ? 'New' : cell(row, 'status'), assignedTo: cell(row, 'assigned_to').isEmpty ? null : cell(row, 'assigned_to'), followUpDate: DateTime.tryParse(cell(row, 'follow_up_date'))));
      }
      setState(() => _leads = parsed);
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV error: $error'))); }
  }

  Future<void> _import() async {
    setState(() => _saving = true);
    try { await ref.read(leadProvider.notifier).importLeads(_leads); if (mounted) Navigator.pop(context); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Import leads')), body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('CSV columns: name, phone, site. Optional: status, follow_up_date, assigned_to.'), const SizedBox(height: 16), OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.upload_file), label: const Text('Choose CSV')), const SizedBox(height: 16), Text('${_leads.length} leads ready to import'), const Spacer(), SizedBox(width: double.infinity, child: FilledButton(onPressed: _leads.isEmpty || _saving ? null : _import, child: Text(_saving ? 'Importing...' : 'Import leads')))])));
}

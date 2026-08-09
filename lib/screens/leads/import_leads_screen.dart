import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';

class ImportLeadsScreen extends ConsumerStatefulWidget {
  const ImportLeadsScreen({super.key});
  @override
  ConsumerState<ImportLeadsScreen> createState() => _ImportLeadsScreenState();
}

class _ImportLeadsScreenState extends ConsumerState<ImportLeadsScreen> {
  List<LeadModel> _leads = [];
  int _skippedRows = 0;
  String? _fileName;
  bool _parsing = false;
  bool _saving = false;
  String? _error;

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _leads = [];
      _skippedRows = 0;
      _fileName = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() => _parsing = true);
    try {
      var text = _decodeBytes(result.files.single.bytes!);
      // Excel/Google Sheets exports on Windows very commonly prefix the
      // file with a UTF-8 byte-order-mark and use \r\n line endings --
      // left as-is, the BOM silently attaches itself to the first header
      // ("name" becomes "\ufeffname"), so "Required columns" fails even
      // though the file looks completely normal when opened. Both of
      // those are almost certainly why import "did nothing" before.
      if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
        text = text.substring(1);
      }
      text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      // A hand-rolled `line.split(',')` (the previous approach) breaks on
      // any field that contains a comma inside quotes -- e.g. an address
      // like "Plot 4, Sector 12" -- which silently shifts every column
      // after it. The csv package handles quoting correctly.
      // Chaining `.convert(text)` straight onto `const CsvToListConverter(...)`
      // makes dart2js treat the whole expression as something it must
      // evaluate at compile time, which fails since `text` isn't a
      // constant. Wrapping the const instance in parentheses fixes that:
      // the converter object itself is still built once as a const value,
      // but the `.convert(text)` call is a normal (non-const) call.
      final rows = (const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      )).convert(text);
      final nonEmptyRows = rows
          .where((row) => row.any((cell) => cell.toString().trim().isNotEmpty))
          .toList();

      if (nonEmptyRows.length < 2) {
        throw const FormatException('CSV has no lead rows.');
      }

      final headers = nonEmptyRows.first
          .map((cell) => cell.toString().trim().toLowerCase())
          .toList();
      final missing = ['name', 'phone', 'site']
          .where((required) => !headers.contains(required))
          .toList();
      if (missing.isNotEmpty) {
        throw FormatException(
          'Missing required column(s): ${missing.join(', ')}. '
          'Found columns: ${headers.join(', ')}.',
        );
      }

      String cell(List<dynamic> row, String name) {
        final index = headers.indexOf(name);
        if (index < 0 || index >= row.length) return '';
        return row[index].toString().trim();
      }

      // Resolve "assigned_to" by Supabase user id, email, or full name --
      // a raw UUID is not something anyone can realistically type into a
      // spreadsheet. Feeding a plain name straight into the uuid column
      // used to make the whole batch insert fail with a database error
      // that was never shown to the user.
      final assigneeById = <String, String>{};
      final assigneeByEmail = <String, String>{};
      final assigneeByName = <String, String>{};
      try {
        final profiles = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, email');
        for (final profile in List<Map<String, dynamic>>.from(profiles)) {
          final id = profile['id']?.toString();
          if (id == null) continue;
          assigneeById[id] = id;
          final email = profile['email']?.toString().trim().toLowerCase();
          if (email != null && email.isNotEmpty) assigneeByEmail[email] = id;
          final name = profile['full_name']?.toString().trim().toLowerCase();
          if (name != null && name.isNotEmpty) assigneeByName[name] = id;
        }
      } catch (_) {
        // If profiles can't be fetched for some reason, imported leads are
        // just left unassigned instead of failing the whole import.
      }

      String? resolveAssignee(String raw) {
        if (raw.isEmpty) return null;
        // A UUID has to actually match a real profile, or it'll violate
        // the foreign key and fail the batch the same way a plain name
        // used to -- fall back to unassigned instead.
        if (_uuidPattern.hasMatch(raw)) return assigneeById[raw];
        final lower = raw.toLowerCase();
        return assigneeByEmail[lower] ?? assigneeByName[lower];
      }

      final parsed = <LeadModel>[];
      var skipped = 0;
      for (final row in nonEmptyRows.skip(1)) {
        final name = cell(row, 'name');
        final phone = cell(row, 'phone');
        if (name.isEmpty || phone.isEmpty) {
          skipped++;
          continue;
        }
        final status = cell(row, 'status');
        final source = cell(row, 'source');
        final assignedToRaw = cell(row, 'assigned_to');
        parsed.add(
          LeadModel(
            name: name,
            phone: phone,
            site: cell(row, 'site'),
            status: status.isEmpty ? 'New' : status,
            source: source.isEmpty ? null : source,
            assignedTo: resolveAssignee(assignedToRaw),
            followUpDate: DateTime.tryParse(cell(row, 'follow_up_date')),
          ),
        );
      }

      if (parsed.isEmpty) {
        throw const FormatException(
          'No valid rows found -- every row is missing a name or phone number.',
        );
      }

      setState(() {
        _leads = parsed;
        _skippedRows = skipped;
        _fileName = result.files.single.name;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'CSV error: $error');
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  /// Tries UTF-8 first (handles Hindi/other non-ASCII text correctly);
  /// falls back to Latin-1 for CSVs saved by older Excel versions in a
  /// different encoding, instead of throwing and leaving import "stuck".
  String _decodeBytes(List<int> bytes) {
    try {
      return const Utf8Codec(allowMalformed: false).decode(bytes);
    } catch (_) {
      return const Latin1Codec().decode(bytes);
    }
  }

  Future<void> _import() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(leadProvider.notifier).importLeads(_leads);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = 'Import failed: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Import leads')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CSV columns: name, phone, site. Optional: status, source, '
            'follow_up_date, assigned_to (email or full name).',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _parsing ? null : _pickFile,
            icon: _parsing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: Text(_parsing ? 'Reading file...' : 'Choose CSV'),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 8),
            Text(_fileName!, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
          const SizedBox(height: 16),
          Text('${_leads.length} lead${_leads.length == 1 ? '' : 's'} ready to import'),
          if (_skippedRows > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$_skippedRows row${_skippedRows == 1 ? '' : 's'} skipped (missing name or phone).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_leads.isNotEmpty) ...[
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _leads.length,
                itemBuilder: (_, index) {
                  final lead = _leads[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline),
                    title: Text(lead.name),
                    subtitle: Text('${lead.phone} • ${lead.site}'),
                  );
                },
              ),
            ),
          ] else
            const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _leads.isEmpty || _saving ? null : _import,
              child: Text(_saving ? 'Importing...' : 'Import leads'),
            ),
          ),
        ],
      ),
    ),
  );
}

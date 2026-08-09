import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';

/// Bulk-imports leads from an Excel (.xlsx) file. CSV import used to live
/// here -- it's gone entirely now (per product decision) so there's only
/// one file format to support, and no more "which delimiter/encoding did
/// this CSV use" guesswork. Sales/telecaller staff can just export
/// straight from Excel/Google Sheets ("Download as .xlsx") and pick that
/// file directly.
class ImportLeadsScreen extends ConsumerStatefulWidget {
  const ImportLeadsScreen({super.key});
  @override
  ConsumerState<ImportLeadsScreen> createState() => _ImportLeadsScreenState();
}

class _ImportLeadsScreenState extends ConsumerState<ImportLeadsScreen> {
  List<LeadModel> _leads = [];
  int _skippedRows = 0;
  int _raggedRows = 0;
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
      _raggedRows = 0;
      _fileName = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() => _parsing = true);
    try {
      final workbook = xls.Excel.decodeBytes(result.files.single.bytes!);
      if (workbook.tables.isEmpty) {
        throw const FormatException('This Excel file has no sheets.');
      }

      // Use the first sheet that actually has rows, not just whichever
      // sheet name comes first -- some exports leave an empty default
      // "Sheet1" and put the real data on a second tab.
      xls.Sheet? sheet;
      for (final name in workbook.tables.keys) {
        final candidate = workbook.tables[name]!;
        if (candidate.maxRows > 0) {
          sheet = candidate;
          break;
        }
      }
      sheet ??= workbook.tables[workbook.tables.keys.first];

      // Convert every row into cleaned strings up front (same shape the
      // old CSV parser worked with) and drop rows that are entirely
      // blank -- Excel sheets very commonly have trailing empty rows.
      final rows = sheet!.rows
          .map((row) => row.map(_cellText).toList())
          .where((row) => row.any((cell) => cell.isNotEmpty))
          .toList();

      if (rows.length < 2) {
        throw const FormatException('This Excel sheet has no lead rows.');
      }

      final headers = rows.first.map((h) => h.toLowerCase()).toList();
      final missing = ['name', 'phone', 'site']
          .where((required) => !headers.contains(required))
          .toList();
      if (missing.isNotEmpty) {
        throw FormatException(
          'Missing required column(s): ${missing.join(', ')}. '
          'Found columns: ${headers.join(', ')}.',
        );
      }

      String cell(List<String> row, String name) {
        final index = headers.indexOf(name);
        if (index < 0 || index >= row.length) return '';
        return row[index];
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
      var raggedRows = 0;
      for (final row in rows.skip(1)) {
        // A row with a different number of columns than the header
        // usually means a merged/split cell somewhere in the sheet --
        // worth flagging separately from a row that's genuinely missing
        // data.
        if (row.length != headers.length) raggedRows++;
        var name = cell(row, 'name');
        final phone = cell(row, 'phone');
        // Name is often left blank when leads come from a call list that
        // only has numbers -- fall back to the phone number itself
        // instead of dropping the row, so nothing gets silently skipped
        // just because a name wasn't typed in.
        if (name.isEmpty && phone.isNotEmpty) name = phone;
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
        final sampleRow = rows.length > 1 ? rows[1] : null;
        final raggedNote = raggedRows > 0
            ? ' $raggedRows row(s) had a different number of columns than '
                  'the header (${headers.length}) -- check for a merged or '
                  'split cell.'
            : '';
        throw FormatException(
          'No valid rows found -- every row is missing a phone number. '
          'Detected columns: ${headers.join(', ')}.$raggedNote'
          '${sampleRow != null ? ' First data row read as: $sampleRow' : ''}',
        );
      }

      setState(() {
        _leads = parsed;
        _skippedRows = skipped;
        _raggedRows = raggedRows;
        _fileName = result.files.single.name;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Excel error: $error');
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  /// Converts one Excel cell to a plain, trimmed string regardless of how
  /// it was typed in the sheet -- text, a typed-in number (phone numbers
  /// are very often entered as numbers, which would otherwise show up as
  /// "9876543210.0"), a date, or a formula result.
  String _cellText(xls.Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    if (value is xls.TextCellValue) return _clean(value.value.toString());
    if (value is xls.IntCellValue) return value.value.toString();
    if (value is xls.DoubleCellValue) {
      final d = value.value;
      return _clean(d == d.roundToDouble() ? d.toInt().toString() : d.toString());
    }
    if (value is xls.BoolCellValue) return value.value.toString();
    if (value is xls.DateCellValue) {
      return '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }
    if (value is xls.DateTimeCellValue) {
      final dt = value.asDateTimeLocal();
      return '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
    }
    if (value is xls.FormulaCellValue) return _clean(value.formula);
    return _clean(value.toString());
  }

  /// Trims a cell and strips invisible characters that regularly sneak
  /// into spreadsheets exported from other tools -- a non-breaking space
  /// (U+00A0), zero-width space (U+200B) or stray byte-order-mark makes a
  /// header fail to match "name" even though it looks completely normal
  /// on screen.
  String _clean(String value) => value
      .replaceAll('\uFEFF', '')
      .replaceAll('\u200B', '')
      .replaceAll('\u00A0', ' ')
      .trim();

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
            'Excel (.xlsx) columns: name, phone, site. Optional: status, '
            'source, follow_up_date, assigned_to (email or full name). If '
            'name is left blank, the phone number is used as the name.',
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
            label: Text(_parsing ? 'Reading file...' : 'Choose Excel file'),
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
              '$_skippedRows row${_skippedRows == 1 ? '' : 's'} skipped (missing phone number).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_raggedRows > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$_raggedRows row${_raggedRows == 1 ? '' : 's'} had an unexpected number '
              'of columns -- double-check for a merged or split cell.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange[800]),
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

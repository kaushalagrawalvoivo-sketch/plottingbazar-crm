import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/plot_model.dart';
import '../../providers/plot_provider.dart';
import '../../providers/site_provider.dart';

class AddPlotScreen extends ConsumerStatefulWidget {
  const AddPlotScreen({super.key});

  @override
  ConsumerState<AddPlotScreen> createState() => _AddPlotScreenState();
}

class _AddPlotScreenState extends ConsumerState<AddPlotScreen> {
  final _formKey = GlobalKey<FormState>();

  final _blockController = TextEditingController();
  final _plotNoController = TextEditingController();
  final _areaController = TextEditingController();
  final _rateController = TextEditingController();

  String? _siteId;
  String _facing = "East";
  bool _isCorner = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(siteProvider.notifier).loadSites());
  }

  @override
  void dispose() {
    _blockController.dispose();
    _plotNoController.dispose();
    _areaController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final plot = PlotModel(
        siteId: _siteId!,
        block: _blockController.text.trim(),
        plotNo: _plotNoController.text.trim(),
        area: double.parse(_areaController.text),
        rate: double.parse(_rateController.text),
        facing: _facing,
        isCorner: _isCorner,
      );

      await ref.read(plotProvider.notifier).addPlot(plot);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save plot: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sites = ref
        .watch(siteProvider)
        .where((site) => site.isActive && site.id != null)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Add Plot")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _siteId,
                decoration: const InputDecoration(
                  labelText: "Site",
                  border: OutlineInputBorder(),
                ),
                items: sites
                    .map(
                      (site) => DropdownMenuItem(
                        value: site.id,
                        child: Text(site.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _siteId = value),
                validator: (value) => value == null ? "Select a site" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _blockController,
                decoration: const InputDecoration(
                  labelText: "Block",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _plotNoController,
                decoration: const InputDecoration(
                  labelText: "Plot Number",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _areaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Area",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final area = double.tryParse(value ?? '');
                  return area == null || area <= 0
                      ? "Enter a valid area"
                      : null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _rateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Rate Per Sq.Ft.",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final rate = double.tryParse(value ?? '');
                  return rate == null || rate <= 0
                      ? "Enter a valid rate"
                      : null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _facing,
                decoration: const InputDecoration(
                  labelText: "Facing",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "East", child: Text("East")),
                  DropdownMenuItem(value: "West", child: Text("West")),
                  DropdownMenuItem(value: "North", child: Text("North")),
                  DropdownMenuItem(value: "South", child: Text("South")),
                ],
                onChanged: (value) {
                  setState(() {
                    _facing = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text("Corner Plot"),
                value: _isCorner,
                onChanged: (value) {
                  setState(() {
                    _isCorner = value;
                  });
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text("Save Plot"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/plot_model.dart';
import '../../providers/plot_provider.dart';
import '../../providers/site_provider.dart';

class EditPlotScreen extends ConsumerStatefulWidget {
  final PlotModel plot;

  const EditPlotScreen({super.key, required this.plot});

  @override
  ConsumerState<EditPlotScreen> createState() => _EditPlotScreenState();
}

class _EditPlotScreenState extends ConsumerState<EditPlotScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _blockController;
  late final TextEditingController _plotNoController;
  late final TextEditingController _areaController;
  late final TextEditingController _rateController;

  late String _siteId;
  late String _facing;
  late bool _isCorner;
  late String _status;

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _siteId = widget.plot.siteId;

    _blockController = TextEditingController(text: widget.plot.block);

    _plotNoController = TextEditingController(text: widget.plot.plotNo);

    _areaController = TextEditingController(text: widget.plot.area.toString());

    _rateController = TextEditingController(text: widget.plot.rate.toString());

    _facing = widget.plot.facing;
    _isCorner = widget.plot.isCorner;
    _status = widget.plot.status;

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

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final updatedPlot = widget.plot.copyWith(
        siteId: _siteId,
        block: _blockController.text.trim(),
        plotNo: _plotNoController.text.trim(),
        area: double.parse(_areaController.text),
        rate: double.parse(_rateController.text),
        facing: _facing,
        isCorner: _isCorner,
        status: _status,
      );

      await ref.read(plotProvider.notifier).updatePlot(updatedPlot);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update plot: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(siteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Plot")),
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
                    .where((site) => site.id != null)
                    .map(
                      (site) => DropdownMenuItem(
                        value: site.id,
                        child: Text(site.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _siteId = value);
                },
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
                  setState(() => _facing = value!);
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: "Status",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "Available",
                    child: Text("Available"),
                  ),
                  DropdownMenuItem(value: "Booked", child: Text("Booked")),
                  DropdownMenuItem(value: "Hold", child: Text("Hold")),
                ],
                onChanged: (value) {
                  setState(() => _status = value!);
                },
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text("Corner Plot"),
                value: _isCorner,
                onChanged: (value) {
                  setState(() => _isCorner = value);
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton(
                  onPressed: _loading ? null : _update,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text("Update Plot"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

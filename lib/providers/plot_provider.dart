import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/plot_service.dart';
import '../models/plot_model.dart';

final plotProvider =
    StateNotifierProvider<PlotNotifier, List<PlotModel>>(
  (ref) => PlotNotifier(),
);

class PlotNotifier extends StateNotifier<List<PlotModel>> {
  PlotNotifier() : super([]);

  final PlotService _service = PlotService();

  Future<void> loadPlots() async {
    state = await _service.getPlots();
  }

  Future<void> refresh() async {
    await loadPlots();
  }

  Future<void> addPlot(PlotModel plot) async {
    await _service.addPlot(plot);
    await loadPlots();
  }

  Future<void> updatePlot(PlotModel plot) async {
    await _service.updatePlot(plot);
    await loadPlots();
  }

  Future<void> deletePlot(String id) async {
    await _service.deletePlot(id);
    await loadPlots();
  }

  Future<void> updateStatus({
    required String id,
    required String status,
  }) async {
    await _service.updateStatus(
      id: id,
      status: status,
    );
    await loadPlots();
  }

  /// All plots of a site
  List<PlotModel> getPlotsBySite(String siteId) {
    return state.where((e) => e.siteId == siteId).toList();
  }

  /// Only available plots
  List<PlotModel> getAvailablePlotsBySite(String siteId) {
    return state.where((e) {
      return e.siteId == siteId &&
          e.status.toLowerCase() == "available";
    }).toList();
  }

  PlotModel? getPlot(String id) {
    try {
      return state.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<PlotModel> search(String keyword) {
    if (keyword.trim().isEmpty) return state;

    final q = keyword.toLowerCase();

    return state.where((plot) {
      return plot.plotNo.toLowerCase().contains(q) ||
          plot.block.toLowerCase().contains(q) ||
          plot.facing.toLowerCase().contains(q);
    }).toList();
  }

  int totalPlots() => state.length;

  int availablePlots() =>
      state.where((e) => e.status == "Available").length;

  int bookedPlots() =>
      state.where((e) => e.status == "Booked").length;

  int holdPlots() =>
      state.where((e) => e.status == "Hold").length;

  double totalInventoryValue() {
    return state.fold(
      0.0,
      (sum, plot) => sum + plot.totalPrice,
    );
  }
}
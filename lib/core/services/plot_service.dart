import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/plot_model.dart';

class PlotService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<PlotModel>> getPlots() async {
    try {
      final response = await _db
          .from('plots')
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((e) => PlotModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint("GET PLOTS ERROR: $e");
      rethrow;
    }
  }

  Future<void> addPlot(PlotModel plot) async {
    try {
      await _db.from('plots').insert(plot.toJson());
      debugPrint("Plot Added Successfully");
    } catch (e) {
      debugPrint("ADD PLOT ERROR: $e");
      rethrow;
    }
  }

  Future<void> updatePlot(PlotModel plot) async {
    try {
      if (plot.id == null) {
        throw Exception("Plot ID is null");
      }

      await _db.from('plots').update(plot.toJson()).eq('id', plot.id!);

      debugPrint("Plot Updated Successfully");
    } catch (e) {
      debugPrint("UPDATE PLOT ERROR: $e");
      rethrow;
    }
  }

  Future<void> deletePlot(String id) async {
    try {
      await _db.from('plots').delete().eq('id', id);

      debugPrint("Plot Deleted Successfully");
    } catch (e) {
      debugPrint("DELETE PLOT ERROR: $e");
      rethrow;
    }
  }

  Future<PlotModel?> getPlotById(String id) async {
    try {
      final response = await _db
          .from('plots')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return PlotModel.fromJson(response);
    } catch (e) {
      debugPrint("GET PLOT BY ID ERROR: $e");
      rethrow;
    }
  }

  Future<void> updateStatus({
    required String id,
    required String status,
  }) async {
    try {
      await _db.from('plots').update({'status': status}).eq('id', id);

      debugPrint("Plot Status Updated");
    } catch (e) {
      debugPrint("STATUS UPDATE ERROR: $e");
      rethrow;
    }
  }

  Future<List<PlotModel>> getPlotsBySite(String siteId) async {
    try {
      final response = await _db
          .from('plots')
          .select()
          .eq('site_id', siteId)
          .order('plot_no');

      return (response as List).map((e) => PlotModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint("GET SITE PLOTS ERROR: $e");
      rethrow;
    }
  }
}

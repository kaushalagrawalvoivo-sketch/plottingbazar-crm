import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/site_service.dart';
import '../models/site_model.dart';

final siteServiceProvider = Provider<SiteService>((ref) {
  return SiteService();
});

final siteProvider = StateNotifierProvider<SiteNotifier, List<SiteModel>>((
  ref,
) {
  return SiteNotifier(ref.read(siteServiceProvider));
});

class SiteNotifier extends StateNotifier<List<SiteModel>> {
  final SiteService _service;

  SiteNotifier(this._service) : super([]);

  Future<void> loadSites() async {
    state = await _service.getSites();
  }

  Future<void> refresh() async {
    await loadSites();
  }

  Future<void> addSite(SiteModel site) async {
    await _service.addSite(site);
    await loadSites();
  }

  Future<void> updateSite(SiteModel site) async {
    await _service.updateSite(site);
    await loadSites();
  }

  Future<void> deleteSite(String id) async {
    await _service.deleteSite(id);
    await loadSites();
  }

  int totalSites() => state.length;

  List<SiteModel> activeSites() =>
      state.where((site) => site.isActive).toList();
}

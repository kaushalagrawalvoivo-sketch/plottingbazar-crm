import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/site_model.dart';

class SiteService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<SiteModel>> getSites() async {
    final response = await _db
        .from('sites')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => SiteModel.fromJson(e))
        .toList();
  }

  Future<void> addSite(SiteModel site) async {
    await _db.from('sites').insert(site.toJson());
  }

  Future<void> updateSite(SiteModel site) async {
    await _db
        .from('sites')
        .update(site.toJson())
        .eq('id', site.id!);
  }

  Future<void> deleteSite(String id) async {
    await _db
        .from('sites')
        .delete()
        .eq('id', id);
  }
}
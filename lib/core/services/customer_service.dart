import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/customer_model.dart';

class CustomerService {
  final _db = Supabase.instance.client;

  // Same 1000-row PostgREST cap as leads (see LeadService) -- paginate so
  // every customer loads, not just the first 1000.
  static const int _pageSize = 1000;

  Future<List<CustomerModel>> getCustomers() async {
    final all = <CustomerModel>[];
    var from = 0;
    while (true) {
      final response = await _db
          .from('customers')
          .select()
          .order('created_at', ascending: false)
          .range(from, from + _pageSize - 1);
      final page = (response as List)
          .map((e) => CustomerModel.fromJson(e))
          .toList();
      all.addAll(page);
      if (page.length < _pageSize) break;
      from += _pageSize;
    }
    return all;
  }

  Future<void> addCustomer(CustomerModel customer) async {
    await _db.from('customers').insert(customer.toJson());
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    if (customer.id == null) return;

    await _db
        .from('customers')
        .update(customer.toJson())
        .eq('id', customer.id!);
  }

  Future<void> deleteCustomer(String id) async {
    await _db.from('customers').delete().eq('id', id);
  }

  Future<CustomerModel?> getCustomerById(String id) async {
    final response = await _db
        .from('customers')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;

    return CustomerModel.fromJson(response);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/customer_service.dart';
import '../models/customer_model.dart';

final customerProvider =
    StateNotifierProvider<CustomerNotifier, List<CustomerModel>>(
      (ref) => CustomerNotifier(),
    );

class CustomerNotifier extends StateNotifier<List<CustomerModel>> {
  CustomerNotifier() : super([]);

  final CustomerService _service = CustomerService();

  Future<void> loadCustomers() async {
    state = await _service.getCustomers();
  }

  Future<void> refresh() async {
    await loadCustomers();
  }

  Future<void> addCustomer(CustomerModel customer) async {
    await _service.addCustomer(customer);
    await loadCustomers();
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await _service.updateCustomer(customer);
    await loadCustomers();
  }

  Future<void> deleteCustomer(String id) async {
    await _service.deleteCustomer(id);
    await loadCustomers();
  }

  int totalCustomers() => state.length;

  List<CustomerModel> search(String keyword) {
    if (keyword.trim().isEmpty) return state;

    final q = keyword.toLowerCase();

    return state.where((customer) {
      return customer.name.toLowerCase().contains(q) ||
          customer.mobile.toLowerCase().contains(q) ||
          (customer.email ?? '').toLowerCase().contains(q);
    }).toList();
  }
}

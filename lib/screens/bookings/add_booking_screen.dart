import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/booking_model.dart';
import '../../models/customer_model.dart';
import '../../models/plot_model.dart';
import '../../models/site_model.dart';

import '../../providers/booking_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/plot_provider.dart';
import '../../providers/site_provider.dart';

class AddBookingScreen extends ConsumerStatefulWidget {
  const AddBookingScreen({super.key});

  @override
  ConsumerState<AddBookingScreen> createState() =>
      _AddBookingScreenState();
}

class _AddBookingScreenState
    extends ConsumerState<AddBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _bookingAmountController =
      TextEditingController();

  final _salePriceController =
      TextEditingController();

  final _discountController =
      TextEditingController(text: "0");

  CustomerModel? _customer;
  SiteModel? _site;
  PlotModel? _plot;

  DateTime _bookingDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await ref.read(customerProvider.notifier).loadCustomers();
      await ref.read(siteProvider.notifier).loadSites();
      await ref.read(plotProvider.notifier).loadPlots();
    });
  }

  @override
  void dispose() {
    _bookingAmountController.dispose();
    _salePriceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerProvider);
    final sites = ref.watch(siteProvider);

    final plotNotifier =
        ref.read(plotProvider.notifier);

    final bookingNotifier =
        ref.read(bookingProvider.notifier);

    final plots = _site == null
        ? <PlotModel>[]
        : plotNotifier.getAvailablePlotsBySite(
            _site!.id!,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Booking"),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<CustomerModel>(
              initialValue: _customer,
              decoration: const InputDecoration(
                labelText: "Customer",
                border: OutlineInputBorder(),
              ),
              items: customers
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _customer = value;
                });
              },
              validator: (value) =>
                  value == null ? "Select Customer" : null,
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<SiteModel>(
              initialValue: _site,
              decoration: const InputDecoration(
                labelText: "Site",
                border: OutlineInputBorder(),
              ),
              items: sites
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _site = value;
                  _plot = null;
                  _salePriceController.clear();
                });
              },
              validator: (value) =>
                  value == null ? "Select Site" : null,
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<PlotModel>(
              initialValue: _plot,
              decoration: const InputDecoration(
                labelText: "Plot",
                border: OutlineInputBorder(),
              ),
              items: plots
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                          "${e.block}-${e.plotNo}"),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _plot = value;

                  if (value != null) {
                    _salePriceController.text =
                        value.totalPrice
                            .toStringAsFixed(0);
                  }
                });
              },
              validator: (value) =>
                  value == null ? "Select Plot" : null,
            ),

            const SizedBox(height: 16),            TextFormField(
              controller: _salePriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Sale Price",
                border: OutlineInputBorder(),
                prefixText: "₹ ",
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Enter Sale Price";
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _bookingAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Booking Amount",
                border: OutlineInputBorder(),
                prefixText: "₹ ",
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Enter Booking Amount";
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Discount",
                border: OutlineInputBorder(),
                prefixText: "₹ ",
              ),
            ),

            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Colors.grey.shade400,
                ),
              ),
              title: const Text("Booking Date"),
              subtitle: Text(
                "${_bookingDate.day}/${_bookingDate.month}/${_bookingDate.year}",
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _bookingDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );

                if (date != null) {
                  setState(() {
                    _bookingDate = date;
                  });
                }
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 55,
              child: FilledButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }

                  final booking = BookingModel(
                    customerId: _customer!.id!,
                    siteId: _site!.id!,
                    plotId: _plot!.id!,
                    bookingAmount: double.parse(
                      _bookingAmountController.text,
                    ),
                    salePrice: double.parse(
                      _salePriceController.text,
                    ),
                    discount: double.tryParse(
                          _discountController.text,
                        ) ??
                        0,
                    bookingDate: _bookingDate,
                  );

                  await bookingNotifier.addBooking(booking);

                  if (!mounted) return;

                  Navigator.pop(context);
                },
                child: const Text("Save Booking"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
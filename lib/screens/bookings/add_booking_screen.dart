// ignore_for_file: use_build_context_synchronously

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
  ConsumerState<AddBookingScreen> createState() => _AddBookingScreenState();
}

class _AddBookingScreenState extends ConsumerState<AddBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _bookingAmountController = TextEditingController();

  final _salePriceController = TextEditingController();

  final _discountController = TextEditingController(text: "0");

  CustomerModel? _customer;
  SiteModel? _site;
  PlotModel? _plot;

  DateTime _bookingDate = DateTime.now();
  bool _saving = false;

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
    final customers = ref
        .watch(customerProvider)
        .where((customer) => customer.isActive && customer.id != null)
        .toList();
    final sites = ref
        .watch(siteProvider)
        .where((site) => site.isActive && site.id != null)
        .toList();

    final plotNotifier = ref.read(plotProvider.notifier);

    final bookingNotifier = ref.read(bookingProvider.notifier);

    final plots = _site == null
        ? <PlotModel>[]
        : plotNotifier.getAvailablePlotsBySite(_site!.id!);

    return Scaffold(
      appBar: AppBar(title: const Text("Add Booking")),
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
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _customer = value;
                });
              },
              validator: (value) => value == null ? "Select Customer" : null,
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<SiteModel>(
              initialValue: _site,
              decoration: const InputDecoration(
                labelText: "Site",
                border: OutlineInputBorder(),
              ),
              items: sites
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _site = value;
                  _plot = null;
                  _salePriceController.clear();
                });
              },
              validator: (value) => value == null ? "Select Site" : null,
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
                      child: Text("${e.block}-${e.plotNo}"),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _plot = value;

                  if (value != null) {
                    _salePriceController.text = value.totalPrice
                        .toStringAsFixed(0);
                  }
                });
              },
              validator: (value) => value == null ? "Select Plot" : null,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _salePriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "Sale Price",
                border: OutlineInputBorder(),
                prefixText: "₹ ",
              ),
              validator: _positiveAmountValidator,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _bookingAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "Booking Amount",
                border: OutlineInputBorder(),
                prefixText: "₹ ",
              ),
              validator: _positiveAmountValidator,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "Discount",
                border: OutlineInputBorder(),
                prefixText: "₹ ",
              ),
              validator: (value) {
                final discount = double.tryParse(value ?? '');
                return discount == null || discount < 0
                    ? "Enter a valid discount"
                    : null;
              },
            ),

            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
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
                onPressed: _saving
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) {
                          return;
                        }

                        final salePrice = double.parse(
                          _salePriceController.text,
                        );
                        final bookingAmount = double.parse(
                          _bookingAmountController.text,
                        );
                        final discount = double.parse(_discountController.text);

                        if (bookingAmount + discount > salePrice) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Booking amount and discount cannot exceed the sale price.',
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() => _saving = true);

                        try {
                          final booking = BookingModel(
                            customerId: _customer!.id!,
                            siteId: _site!.id!,
                            plotId: _plot!.id!,
                            bookingAmount: bookingAmount,
                            salePrice: salePrice,
                            discount: discount,
                            bookingDate: _bookingDate,
                          );

                          await bookingNotifier.addBooking(booking);

                          if (!mounted) return;
                          Navigator.pop(context);
                        } catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not save booking: $error'),
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Save Booking"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _positiveAmountValidator(String? value) {
    final amount = double.tryParse(value ?? '');
    return amount == null || amount <= 0 ? 'Enter an amount above zero' : null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/booking_model.dart';
import '../../models/plot_model.dart';

import '../../providers/booking_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/plot_provider.dart';
import '../../providers/site_provider.dart';

class EditBookingScreen extends ConsumerStatefulWidget {
  final BookingModel booking;

  const EditBookingScreen({
    super.key,
    required this.booking,
  });

  @override
  ConsumerState<EditBookingScreen> createState() =>
      _EditBookingScreenState();
}

class _EditBookingScreenState
    extends ConsumerState<EditBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _salePriceController;
  late TextEditingController _bookingAmountController;
  late TextEditingController _discountController;

  String? _customerId;
  String? _siteId;
  String? _plotId;

  late DateTime _bookingDate;

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _salePriceController = TextEditingController(
      text: widget.booking.salePrice.toString(),
    );

    _bookingAmountController = TextEditingController(
      text: widget.booking.bookingAmount.toString(),
    );

    _discountController = TextEditingController(
      text: widget.booking.discount.toString(),
    );

    _customerId = widget.booking.customerId;
    _siteId = widget.booking.siteId;
    _plotId = widget.booking.plotId;
    _bookingDate = widget.booking.bookingDate;

    Future.microtask(() async {
      await ref.read(customerProvider.notifier).loadCustomers();
      await ref.read(siteProvider.notifier).loadSites();
      await ref.read(plotProvider.notifier).loadPlots();
    });
  }

  @override
  void dispose() {
    _salePriceController.dispose();
    _bookingAmountController.dispose();
    _discountController.dispose();
    super.dispose();
  }  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerProvider);
    final sites = ref.watch(siteProvider);

    final plotNotifier = ref.read(plotProvider.notifier);
    final bookingNotifier = ref.read(bookingProvider.notifier);

    final plots = _siteId == null
        ? <PlotModel>[]
        : plotNotifier.getPlotsBySite(_siteId!);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Booking"),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            DropdownButtonFormField<String>(
              initialValue: _customerId,
              decoration: const InputDecoration(
                labelText: "Customer",
                border: OutlineInputBorder(),
              ),
              items: customers
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(e.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _customerId = v;
                });
              },
              validator: (v) =>
                  v == null ? "Select Customer" : null,
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _siteId,
              decoration: const InputDecoration(
                labelText: "Site",
                border: OutlineInputBorder(),
              ),
              items: sites
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(e.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _siteId = v;
                  _plotId = null;
                });
              },
              validator: (v) =>
                  v == null ? "Select Site" : null,
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _plotId,
              decoration: const InputDecoration(
                labelText: "Plot",
                border: OutlineInputBorder(),
              ),
              items: plots
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text("${e.block}-${e.plotNo}"),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _plotId = v;

                  final plot = plots.firstWhere(
                    (e) => e.id == v,
                  );

                  _salePriceController.text =
                      plot.totalPrice.toStringAsFixed(0);
                });
              },
              validator: (v) =>
                  v == null ? "Select Plot" : null,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _salePriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Sale Price",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _bookingAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Booking Amount",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Discount",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Colors.grey.shade400,
                ),
              ),
              title: const Text("Booking Date"),
              subtitle: Text(
                DateFormat("dd MMM yyyy")
                    .format(_bookingDate),
              ),
              trailing: const Icon(Icons.calendar_today),              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _bookingDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );

                if (picked != null) {
                  setState(() {
                    _bookingDate = picked;
                  });
                }
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 55,
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) {
                          return;
                        }

                        setState(() {
                          _loading = true;
                        });

                        try {
                          final updatedBooking = widget.booking.copyWith(
                            customerId: _customerId!,
                            siteId: _siteId!,
                            plotId: _plotId!,
                            salePrice: double.tryParse(
                                  _salePriceController.text,
                                ) ??
                                0,
                            bookingAmount: double.tryParse(
                                  _bookingAmountController.text,
                                ) ??
                                0,
                            discount: double.tryParse(
                                  _discountController.text,
                                ) ??
                                0,
                            bookingDate: _bookingDate,
                          );

                          await bookingNotifier.updateBooking(
                            updatedBooking,
                          );

                          if (!mounted) return;

                          Navigator.pop(context, true);
                        } catch (e) {
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Update Failed : $e",
                              ),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _loading = false;
                            });
                          }
                        }
                      },
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Update Booking"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
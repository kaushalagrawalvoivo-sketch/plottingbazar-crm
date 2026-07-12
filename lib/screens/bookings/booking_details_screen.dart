import 'package:flutter/material.dart';

import '../../models/booking_model.dart';

class BookingDetailsScreen extends StatelessWidget {
  final BookingModel booking;

  const BookingDetailsScreen({
    super.key,
    required this.booking,
  });

  Widget _tile(String title, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Details"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile("Customer ID", booking.customerId),
          _tile("Site ID", booking.siteId),
          _tile("Plot ID", booking.plotId),
          _tile("Status", booking.status),
          _tile(
            "Booking Amount",
            "₹ ${booking.bookingAmount.toStringAsFixed(2)}",
          ),
          _tile(
            "Sale Price",
            "₹ ${booking.salePrice.toStringAsFixed(2)}",
          ),
          _tile(
            "Discount",
            "₹ ${booking.discount.toStringAsFixed(2)}",
          ),
          _tile(
            "Balance",
            "₹ ${booking.balance.toStringAsFixed(2)}",
          ),
          _tile(
            "Booking Date",
            booking.bookingDate.toString().split(' ').first,
          ),
          if (booking.createdAt != null)
            _tile(
              "Created At",
              booking.createdAt.toString(),
            ),
        ],
      ),
    );
  }
}
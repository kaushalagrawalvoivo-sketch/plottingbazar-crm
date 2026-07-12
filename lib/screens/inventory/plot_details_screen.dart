import 'package:flutter/material.dart';

import '../../models/plot_model.dart';

class PlotDetailsScreen extends StatelessWidget {
  final PlotModel plot;

  const PlotDetailsScreen({super.key, required this.plot});

  Widget _tile(String title, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value.isEmpty ? "-" : value),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Booked":
        return Colors.red;
      case "Hold":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Plot ${plot.plotNo}")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: _statusColor(plot.status),
            child: const Icon(Icons.home_work, color: Colors.white, size: 42),
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              "Plot ${plot.plotNo}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 24),

          _tile("Site ID", plot.siteId, Icons.location_city),

          _tile("Block", plot.block, Icons.grid_view),

          _tile("Area", "${plot.area} Sq.Ft.", Icons.square_foot),

          _tile(
            "Rate",
            "₹ ${plot.rate.toStringAsFixed(2)} / Sq.Ft.",
            Icons.currency_rupee,
          ),

          _tile(
            "Total Value",
            "₹ ${plot.totalPrice.toStringAsFixed(2)}",
            Icons.account_balance_wallet,
          ),

          _tile("Facing", plot.facing, Icons.explore),

          _tile("Corner Plot", plot.isCorner ? "Yes" : "No", Icons.crop_square),

          _tile("Status", plot.status, Icons.verified),

          if (plot.createdAt != null)
            _tile(
              "Created At",
              plot.createdAt.toString(),
              Icons.calendar_today,
            ),
        ],
      ),
    );
  }
}

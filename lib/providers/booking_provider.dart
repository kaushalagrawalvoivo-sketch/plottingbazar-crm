import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/booking_service.dart';
import '../models/booking_model.dart';

final bookingProvider =
    StateNotifierProvider<BookingNotifier, List<BookingModel>>(
      (ref) => BookingNotifier(),
    );

class BookingNotifier extends StateNotifier<List<BookingModel>> {
  BookingNotifier() : super([]);

  final BookingService _service = BookingService();

  Future<void> loadBookings() async {
    state = await _service.getBookings();
  }

  Future<void> refresh() async => loadBookings();

  Future<void> addBooking(BookingModel booking) async {
    await _service.addBooking(booking);
    await loadBookings();
  }

  Future<void> updateBooking(
    BookingModel booking, {
    required String previousPlotId,
  }) async {
    await _service.updateBooking(booking, previousPlotId: previousPlotId);
    await loadBookings();
  }

  Future<void> deleteBooking({
    required String bookingId,
    required String plotId,
  }) async {
    await _service.deleteBooking(bookingId, plotId);

    await loadBookings();
  }

  List<BookingModel> search(String keyword) {
    if (keyword.trim().isEmpty) return state;

    final q = keyword.toLowerCase();

    return state.where((booking) {
      return booking.customerId.toLowerCase().contains(q) ||
          booking.siteId.toLowerCase().contains(q) ||
          booking.plotId.toLowerCase().contains(q);
    }).toList();
  }

  int totalBookings() => state.length;

  double totalSaleValue() => state.fold(0.0, (sum, e) => sum + e.salePrice);

  double totalBookingAmount() =>
      state.fold(0.0, (sum, e) => sum + e.bookingAmount);

  double totalDiscount() => state.fold(0.0, (sum, e) => sum + e.discount);

  double totalBalance() => state.fold(0.0, (sum, e) => sum + e.balance);
}

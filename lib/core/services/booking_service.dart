import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/booking_model.dart';

class BookingService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<BookingModel>> getBookings() async {
    try {
      final response = await _db
          .from('bookings')
          .select()
          .order('booking_date', ascending: false);

      return (response as List)
          .map((e) => BookingModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint("GET BOOKINGS ERROR: $e");
      rethrow;
    }
  }

  Future<void> addBooking(BookingModel booking) async {
    try {
      await _db.from('bookings').insert(booking.toJson());

      await _db
          .from('plots')
          .update({
            'status': 'Booked',
          })
          .eq('id', booking.plotId);

      debugPrint("Booking Added Successfully");
    } catch (e) {
      debugPrint("ADD BOOKING ERROR: $e");
      rethrow;
    }
  }

  Future<void> updateBooking(BookingModel booking) async {
    try {
      if (booking.id == null) {
        throw Exception("Booking ID is null");
      }

      await _db
          .from('bookings')
          .update(booking.toJson())
          .eq('id', booking.id!);

      debugPrint("Booking Updated Successfully");
    } catch (e) {
      debugPrint("UPDATE BOOKING ERROR: $e");
      rethrow;
    }
  }

  Future<void> deleteBooking(
    String bookingId,
    String plotId,
  ) async {
    try {
      await _db
          .from('bookings')
          .delete()
          .eq('id', bookingId);

      await _db
          .from('plots')
          .update({
            'status': 'Available',
          })
          .eq('id', plotId);

      debugPrint("Booking Deleted Successfully");
    } catch (e) {
      debugPrint("DELETE BOOKING ERROR: $e");
      rethrow;
    }
  }

  Future<BookingModel?> getBookingById(String id) async {
    try {
      final response = await _db
          .from('bookings')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return BookingModel.fromJson(response);
    } catch (e) {
      debugPrint("GET BOOKING ERROR: $e");
      rethrow;
    }
  }
}
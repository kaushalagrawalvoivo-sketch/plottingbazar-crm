class BookingModel {
  final String? id;

  final String customerId;
  final String siteId;
  final String plotId;

  final double bookingAmount;
  final double salePrice;
  final double discount;

  final String status;

  final DateTime bookingDate;
  final DateTime? createdAt;

  const BookingModel({
    this.id,
    required this.customerId,
    required this.siteId,
    required this.plotId,
    required this.bookingAmount,
    required this.salePrice,
    this.discount = 0,
    this.status = "Booked",
    required this.bookingDate,
    this.createdAt,
  });

  double get balance =>
      salePrice - discount - bookingAmount;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id']?.toString(),
      customerId: json['customer_id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      plotId: json['plot_id']?.toString() ?? '',
      bookingAmount: (json['booking_amount'] ?? 0).toDouble(),
      salePrice: (json['sale_price'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      status: json['status'] ?? 'Booked',
      bookingDate: DateTime.parse(json['booking_date']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'site_id': siteId,
      'plot_id': plotId,
      'booking_amount': bookingAmount,
      'sale_price': salePrice,
      'discount': discount,
      'status': status,
      'booking_date': bookingDate.toIso8601String(),
    };
  }

  BookingModel copyWith({
    String? id,
    String? customerId,
    String? siteId,
    String? plotId,
    double? bookingAmount,
    double? salePrice,
    double? discount,
    String? status,
    DateTime? bookingDate,
    DateTime? createdAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      siteId: siteId ?? this.siteId,
      plotId: plotId ?? this.plotId,
      bookingAmount: bookingAmount ?? this.bookingAmount,
      salePrice: salePrice ?? this.salePrice,
      discount: discount ?? this.discount,
      status: status ?? this.status,
      bookingDate: bookingDate ?? this.bookingDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
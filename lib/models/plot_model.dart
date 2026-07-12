class PlotModel {
  final String? id;
  final String siteId;
  final String block;
  final String plotNo;
  final double area;
  final double rate;
  final String facing;
  final bool isCorner;
  final String status;
  final DateTime? createdAt;

  PlotModel({
    this.id,
    required this.siteId,
    required this.block,
    required this.plotNo,
    required this.area,
    required this.rate,
    required this.facing,
    this.isCorner = false,
    this.status = "Available",
    this.createdAt,
  });

  double get totalPrice => area * rate;

  factory PlotModel.fromJson(Map<String, dynamic> json) {
    return PlotModel(
      id: json['id']?.toString(),
      siteId: json['site_id']?.toString() ?? '',
      block: json['block'] ?? '',
      plotNo: json['plot_no'] ?? '',
      area: (json['area'] ?? 0).toDouble(),
      rate: (json['rate'] ?? 0).toDouble(),
      facing: json['facing'] ?? '',
      isCorner: json['is_corner'] ?? false,
      status: json['status'] ?? 'Available',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'site_id': siteId,
      'block': block,
      'plot_no': plotNo,
      'area': area,
      'rate': rate,
      'facing': facing,
      'is_corner': isCorner,
      'status': status,
    };

    if (id != null) {
      data['id'] = id;
    }

    return data;
  }

  PlotModel copyWith({
    String? id,
    String? siteId,
    String? block,
    String? plotNo,
    double? area,
    double? rate,
    String? facing,
    bool? isCorner,
    String? status,
    DateTime? createdAt,
  }) {
    return PlotModel(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      block: block ?? this.block,
      plotNo: plotNo ?? this.plotNo,
      area: area ?? this.area,
      rate: rate ?? this.rate,
      facing: facing ?? this.facing,
      isCorner: isCorner ?? this.isCorner,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

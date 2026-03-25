class GoldPrice {
  final String date;
  final List<double> values; // [USD, EUR, GBP]

  const GoldPrice({required this.date, required this.values});

  factory GoldPrice.fromJson(Map<String, dynamic> json) {
    final raw = json['v'] as List<dynamic>;
    return GoldPrice(
      date: json['d'] as String,
      values: raw.map((e) => (e as num).toDouble()).toList(),
    );
  }

  double? priceForCurrency(int cur) {
    if (cur < 0 || cur >= values.length) return null;
    final v = values[cur];
    return v > 0 ? v : null;
  }
}

class GoldDayData {
  final String date;
  final GoldPrice? am;
  final GoldPrice? pm;

  const GoldDayData({required this.date, this.am, this.pm});
}

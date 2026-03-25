class Metal {
  final String code;   // XAU, XAG, XPT, XPD
  final String name;   // Золото, Серебро...
  final String label;  // Au, Ag, Pt, Pd
  final String amUrl;
  final String? pmUrl; // null для серебра (одна фиксация)
  final bool hasPm;

  const Metal({
    required this.code,
    required this.name,
    required this.label,
    required this.amUrl,
    this.pmUrl,
    required this.hasPm,
  });

  static const List<Metal> all = [
    Metal(
      code: 'XAU',
      name: 'Золото',
      label: 'Au',
      amUrl: 'https://prices.lbma.org.uk/json/gold_am.json',
      pmUrl: 'https://prices.lbma.org.uk/json/gold_pm.json',
      hasPm: true,
    ),
    Metal(
      code: 'XAG',
      name: 'Серебро',
      label: 'Ag',
      amUrl: 'https://prices.lbma.org.uk/json/silver.json',
      hasPm: false,
    ),
    Metal(
      code: 'XPT',
      name: 'Платина',
      label: 'Pt',
      amUrl: 'https://prices.lbma.org.uk/json/platinum_am.json',
      pmUrl: 'https://prices.lbma.org.uk/json/platinum_pm.json',
      hasPm: true,
    ),
    Metal(
      code: 'XPD',
      name: 'Палладий',
      label: 'Pd',
      amUrl: 'https://prices.lbma.org.uk/json/palladium_am.json',
      pmUrl: 'https://prices.lbma.org.uk/json/palladium_pm.json',
      hasPm: true,
    ),
  ];
}

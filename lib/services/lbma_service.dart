import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gold_price.dart';
import '../models/metal.dart';

class LbmaService {
  // Cache per metal code: 'XAU' -> list
  final Map<String, List<GoldPrice>> _cacheAm = {};
  final Map<String, List<GoldPrice>> _cachePm = {};

  Future<void> _ensureLoaded(Metal metal) async {
    if (_cacheAm.containsKey(metal.code)) return;

    if (metal.hasPm && metal.pmUrl != null) {
      final results = await Future.wait([
        http.get(Uri.parse(metal.amUrl)),
        http.get(Uri.parse(metal.pmUrl!)),
      ]);
      if (results[0].statusCode == 200) {
        final List<dynamic> j = json.decode(results[0].body);
        _cacheAm[metal.code] = j.map((e) => GoldPrice.fromJson(e)).toList();
      } else {
        throw Exception('Ошибка загрузки AM: ${results[0].statusCode}');
      }
      if (results[1].statusCode == 200) {
        final List<dynamic> j = json.decode(results[1].body);
        _cachePm[metal.code] = j.map((e) => GoldPrice.fromJson(e)).toList();
      } else {
        _cachePm[metal.code] = [];
      }
    } else {
      // Silver: одна фиксация (нет AM/PM)
      final resp = await http.get(Uri.parse(metal.amUrl));
      if (resp.statusCode == 200) {
        final List<dynamic> j = json.decode(resp.body);
        _cacheAm[metal.code] = j.map((e) => GoldPrice.fromJson(e)).toList();
        _cachePm[metal.code] = [];
      } else {
        throw Exception('Ошибка загрузки: ${resp.statusCode}');
      }
    }
  }

  Future<GoldDayData?> getByDate(String dateStr, Metal metal) async {
    await _ensureLoaded(metal);
    final am = _cacheAm[metal.code]?.where((e) => e.date == dateStr).firstOrNull;
    final pm = _cachePm[metal.code]?.where((e) => e.date == dateStr).firstOrNull;
    if (am == null && pm == null) return null;
    return GoldDayData(date: dateStr, am: am, pm: pm);
  }

  Future<List<GoldDayData>> getByRange(String from, String to, Metal metal) async {
    await _ensureLoaded(metal);
    final Map<String, GoldDayData> map = {};
    for (final i in _cacheAm[metal.code] ?? <GoldPrice>[]) {
      if (i.date.compareTo(from) >= 0 && i.date.compareTo(to) <= 0) {
        map[i.date] = GoldDayData(date: i.date, am: i, pm: null);
      }
    }
    for (final i in _cachePm[metal.code] ?? <GoldPrice>[]) {
      if (i.date.compareTo(from) >= 0 && i.date.compareTo(to) <= 0) {
        if (map.containsKey(i.date)) {
          map[i.date] = GoldDayData(date: i.date, am: map[i.date]!.am, pm: i);
        } else {
          map[i.date] = GoldDayData(date: i.date, am: null, pm: i);
        }
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}

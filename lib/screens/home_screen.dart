import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/lbma_service.dart';
import '../models/gold_price.dart';
import '../models/metal.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final LbmaService _svc = LbmaService();

  // Selected metal
  Metal _metal = Metal.all[0]; // Gold by default

  DateTime _selDate = DateTime.now();
  GoldDayData? _singleRes;
  bool _singleLoad = false;
  String? _singleErr;

  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  List<GoldDayData> _histRes = [];
  bool _histLoad = false;
  String? _histErr;

  int _cur = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  String _ds(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  void _changeMetal(Metal m) {
    if (m.code == _metal.code) return;
    setState(() {
      _metal = m;
      _singleRes = null;
      _singleErr = null;
      _histRes = [];
      _histErr = null;
    });
  }

  Future<void> _pick(BuildContext ctx, DateTime init, Function(DateTime) cb) async {
    final d = await showDatePicker(
      context: ctx, initialDate: init,
      firstDate: DateTime(1968), lastDate: DateTime.now(),
      builder: (c, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: LFC.red, onPrimary: Colors.white,
            surface: LFC.card, onSurface: LFC.text,
          ),
          dialogBackgroundColor: LFC.bg2,
        ),
        child: child!,
      ),
    );
    if (d != null) cb(d);
  }

  // ==================== FETCH SINGLE ====================
  Future<void> _fetchSingle() async {
    setState(() { _singleLoad = true; _singleErr = null; _singleRes = null; });
    try {
      var r = await _svc.getByDate(_ds(_selDate), _metal);
      if (r == null) {
        for (int o = 1; o <= 5; o++) {
          final nd = _selDate.subtract(Duration(days: o));
          r = await _svc.getByDate(_ds(nd), _metal);
          if (r != null) {
            setState(() {
              _singleRes = r; _singleLoad = false;
              _singleErr = 'Нет данных за ${LFC.fmtDate(_ds(_selDate))}. Ближайшая дата:';
            });
            return;
          }
        }
      }
      setState(() {
        _singleRes = r; _singleLoad = false;
        if (r == null) _singleErr = 'Нет данных за ${LFC.fmtDate(_ds(_selDate))}.';
      });
    } catch (e) {
      setState(() { _singleLoad = false; _singleErr = '$e'; });
    }
  }

  // ==================== FETCH HISTORY ====================
  Future<void> _fetchHist() async {
    setState(() { _histLoad = true; _histErr = null; _histRes = []; });
    try {
      final r = await _svc.getByRange(_ds(_from), _ds(_to), _metal);
      setState(() {
        _histRes = r; _histLoad = false;
        if (r.isEmpty) _histErr = 'Нет данных за период.';
      });
    } catch (e) {
      setState(() { _histLoad = false; _histErr = '$e'; });
    }
  }

  // ==================== EXPORT EXCEL (CSV) ====================
  Future<void> _exportExcel() async {
    if (_histRes.isEmpty) return;

    final currency = LFC.currencies[_cur];
    final rows = <List<dynamic>>[
      ['Дата', 'AM ($currency)', _metal.hasPm ? 'PM ($currency)' : ''],
    ];
    for (final r in _histRes) {
      rows.add([
        r.date,
        r.am?.priceForCurrency(_cur) ?? '',
        _metal.hasPm ? (r.pm?.priceForCurrency(_cur) ?? '') : '',
      ]);
    }

    final csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    final bom = '\uFEFF';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/lbma_${_metal.code.toLowerCase()}_${_ds(_from)}_${_ds(_to)}.csv');
    await file.writeAsString(bom + csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'LBMA ${_metal.name} $currency (${LFC.fmtDate(_ds(_from))} — ${LFC.fmtDate(_ds(_to))})',
    );
  }

  // ==================== WIDGETS ====================

  PreferredSizeWidget _buildAppBar() {
    final screenH = MediaQuery.of(context).size.height;
    final appBarH = screenH * 0.21;
    final hPad = MediaQuery.of(context).size.width * 0.05;
    return PreferredSize(
      preferredSize: Size.fromHeight(appBarH),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [LFC.red, LFC.redDark],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Title row
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, screenH * 0.012, hPad, 0),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: LFC.gold, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: LFC.gold.withOpacity(0.4), blurRadius: 12)],
                      ),
                      child: Center(
                        child: Text(_metal.label, style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: LFC.redDarker, letterSpacing: 0.5,
                        )),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LBMA METALS', style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: 1.5,
                        )),
                        Text('LONDON BULLION MARKET · AM & PM FIXING', style: TextStyle(
                          fontSize: 10, color: Colors.white70, letterSpacing: 0.8,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenH * 0.01),
              // Metal selector
              _metalSelector(),
              const Spacer(),
              Container(height: 3, color: LFC.gold),
              Container(
                color: LFC.bg2,
                child: TabBar(
                  controller: _tab,
                  indicatorColor: LFC.red,
                  indicatorWeight: 3,
                  labelColor: LFC.gold,
                  unselectedLabelColor: LFC.muted,
                  labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1,
                  ),
                  tabs: const [
                    Tab(text: 'ЦЕНА НА ДАТУ'),
                    Tab(text: 'ИСТОРИЯ'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Metal selector: 4 buttons in a row
  Widget _metalSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: Metal.all.map((m) {
          final selected = m.code == _metal.code;
          return Expanded(
            child: GestureDetector(
              onTap: () => _changeMetal(m),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? LFC.gold.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: selected ? LFC.gold : Colors.white.withOpacity(0.15),
                    width: selected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m.label, style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: selected ? LFC.gold : Colors.white70,
                      letterSpacing: 0.5,
                    )),
                    Text(m.name, style: TextStyle(
                      fontSize: 9,
                      color: selected ? LFC.gold.withOpacity(0.85) : Colors.white38,
                      letterSpacing: 0.3,
                    )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _currencySelector() {
    return Row(
      children: List.generate(3, (i) {
        final on = i == _cur;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => setState(() => _cur = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: on ? LFC.goldDim : Colors.transparent,
                border: Border.all(color: on ? LFC.gold.withOpacity(0.3) : LFC.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(LFC.currencies[i], style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: on ? LFC.gold : LFC.muted, letterSpacing: 0.5,
              )),
            ),
          ),
        );
      }),
    );
  }

  Widget _dateBtn(String label, DateTime date, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: LFC.card, border: Border.all(color: LFC.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: LFC.muted)),
              const SizedBox(height: 4),
              Text(LFC.fmtDate(_ds(date)), style: const TextStyle(fontSize: 15, color: LFC.text)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(String text, bool loading, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [LFC.red, LFC.redDark]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: LFC.red.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          child: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
              : Text(text),
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) {
    return Text(t, style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700,
      color: LFC.gold, letterSpacing: 1.5,
    ));
  }

  Widget _errorCard(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LFC.red.withOpacity(0.1),
          border: Border.all(color: LFC.red.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(msg, style: const TextStyle(fontSize: 13, color: LFC.redLight)),
      ),
    );
  }

  Widget _warnCard(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LFC.goldDim,
          border: Border.all(color: LFC.gold.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(msg, style: const TextStyle(fontSize: 13, color: LFC.gold)),
      ),
    );
  }

  // ==================== SINGLE TAB ====================
  Widget _buildSingleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ВЫБЕРИТЕ ДАТУ'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _pick(context, _selDate, (d) => setState(() => _selDate = d)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: LFC.card, border: Border.all(color: LFC.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(LFC.fmtDate(_ds(_selDate)), style: const TextStyle(fontSize: 16, color: LFC.text)),
                  const Icon(Icons.calendar_today, size: 18, color: LFC.muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _actionBtn('ПОКАЗАТЬ ЦЕНУ', _singleLoad, _fetchSingle),

          if (_singleErr != null && _singleRes != null) _warnCard(_singleErr!),
          if (_singleErr != null && _singleRes == null) _errorCard(_singleErr!),
          if (_singleRes != null) _buildPriceCard(_singleRes!),
        ],
      ),
    );
  }

  Widget _buildPriceCard(GoldDayData data) {
    final aP = data.am?.priceForCurrency(_cur);
    final pP = data.pm?.priceForCurrency(_cur);
    final diff = (aP != null && pP != null) ? pP - aP : null;
    final pct = diff != null && aP != 0 ? (diff / aP! * 100) : null;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        decoration: BoxDecoration(
          color: LFC.card, border: Border.all(color: LFC.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [LFC.red, LFC.gold]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _currencySelector(),
                  const SizedBox(height: 12),
                  Text(LFC.fmtDate(data.date), style: const TextStyle(fontSize: 14, color: LFC.text2)),
                  const SizedBox(height: 12),
                  _priceRow(_metal.hasPm ? 'AM' : 'Fix', _metal.hasPm ? '10:30 London' : _metal.name, aP, true),
                  Container(height: 1, color: LFC.border),
                  _priceRow('PM', '15:00 London', _metal.hasPm ? pP : null, false),
                  if (diff != null) ...[
                    Container(height: 1, color: LFC.border.withOpacity(0.5)),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Δ PM−AM', style: TextStyle(
                            fontSize: 14, color: LFC.text2, fontWeight: FontWeight.w600, letterSpacing: 0.5,
                          )),
                          Text(
                            '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(2)} (${diff > 0 ? "+" : ""}${pct!.toStringAsFixed(3)}%)',
                            style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: diff > 0 ? LFC.green : diff < 0 ? LFC.redLight : LFC.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Цена за 1 тройскую унцию (31.1 г) · LBMA · ${_metal.name}',
                    style: const TextStyle(fontSize: 11, color: LFC.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String badge, String label, double? price, bool isAm) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isAm ? LFC.green.withOpacity(0.15) : LFC.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(badge, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: isAm ? LFC.green : const Color(0xFFE8384F),
                letterSpacing: 1,
              )),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: LFC.text2)),
          ]),
          Text(LFC.fmtPrice(price, _cur), style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700, color: LFC.text,
          )),
        ],
      ),
    );
  }

  // ==================== HISTORY TAB ====================
  Widget _buildHistTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('ПЕРИОД'),
              const SizedBox(height: 10),
              Row(children: [
                _dateBtn('С', _from, () => _pick(context, _from, (d) => setState(() => _from = d))),
                const SizedBox(width: 10),
                _dateBtn('По', _to, () => _pick(context, _to, (d) => setState(() => _to = d))),
              ]),
              const SizedBox(height: 16),
              _actionBtn('ЗАГРУЗИТЬ', _histLoad, _fetchHist),
            ],
          ),
        ),

        if (_histErr != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _errorCard(_histErr!)),

        if (_histRes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(child: _currencySelector()),
                GestureDetector(
                  onTap: _exportExcel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: LFC.green.withOpacity(0.15),
                      border: Border.all(color: LFC.green.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.table_chart, size: 16, color: LFC.green),
                        SizedBox(width: 6),
                        Text('Excel', style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: LFC.green, letterSpacing: 0.5,
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildStats(),
          Expanded(child: _buildTable()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              '${_histRes.length} записей · ${LFC.currencies[_cur]} за тройскую унцию · ${_metal.name} · LBMA',
              style: const TextStyle(fontSize: 11, color: LFC.muted),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStats() {
    final all = <double>[];
    for (final r in _histRes) {
      final a = r.am?.priceForCurrency(_cur);
      final p = r.pm?.priceForCurrency(_cur);
      if (a != null && a > 0) all.add(a);
      if (p != null && p > 0) all.add(p);
    }
    if (all.isEmpty) return const SizedBox();
    all.sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(children: [
        _statCard('Мин', all.first, LFC.redLight),
        const SizedBox(width: 8),
        _statCard('Средн', all.reduce((a, b) => a + b) / all.length, LFC.gold),
        const SizedBox(width: 8),
        _statCard('Макс', all.last, LFC.green),
      ]),
    );
  }

  Widget _statCard(String label, double val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LFC.card, border: Border.all(color: LFC.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text(label, style: const TextStyle(
            fontSize: 11, color: LFC.muted, fontWeight: FontWeight.w700, letterSpacing: 1,
          )),
          const SizedBox(height: 4),
          Text(LFC.fmtPrice(val, _cur), style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: color,
          )),
          const SizedBox(height: 8),
          Container(height: 2, decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(1),
          )),
        ]),
      ),
    );
  }

  Widget _buildTable() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: LFC.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [LFC.redDark, LFC.redDarker]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Expanded(flex: 3, child: Text('ДАТА', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1,
              ))),
              Expanded(flex: 2, child: Text(_metal.hasPm ? 'AM' : 'FIX', textAlign: TextAlign.right, style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1,
              ))),
              Expanded(flex: 2, child: Text(_metal.hasPm ? 'PM' : '', textAlign: TextAlign.right, style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1,
              ))),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _histRes.length,
              itemBuilder: (ctx, idx) {
                final r = _histRes[idx];
                final a = r.am?.priceForCurrency(_cur);
                final p = r.pm?.priceForCurrency(_cur);
                return Container(
                  decoration: BoxDecoration(
                    color: idx.isEven ? Colors.transparent : Colors.white.withOpacity(0.015),
                    border: Border(top: BorderSide(color: LFC.border, width: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(LFC.fmtDate(r.date),
                      style: const TextStyle(fontSize: 13, color: LFC.text2))),
                    Expanded(flex: 2, child: Text(LFC.fmtPrice(a, _cur),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: LFC.text))),
                    Expanded(flex: 2, child: Text(_metal.hasPm ? LFC.fmtPrice(p, _cur) : '',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: LFC.text))),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ==================== FOOTER ====================
  Widget _buildFooter() {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      padding: EdgeInsets.symmetric(vertical: screenH * 0.016),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LFC.border)),
      ),
      child: const Column(
        children: [
          Text("YOU'LL NEVER WALK ALONE", style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: LFC.red, letterSpacing: 3,
          )),
          SizedBox(height: 4),
          Text('Туткабоев Канат', style: TextStyle(
            fontSize: 11, color: LFC.muted, letterSpacing: 1,
          )),
        ],
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildSingleTab(),
                _buildHistTab(),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }
}

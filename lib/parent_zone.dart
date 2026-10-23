import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bin.dart';
import 'doc_store.dart';
import 'kids_ui.dart';
import 'pin_pad.dart';
import 'players.dart';
import 'progress.dart';
import 'tv_link.dart';

// ======================================================================
// PARENT ZONE: progress report for every child, a daily play-time limit and a PIN.
// The PIN, the limit and the time used are saved with the other app settings.
// ======================================================================

class ParentPrefs {
  ParentPrefs._();

  static String _day() {
    final d = DateTime.now();
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static Future<String> pin() async => (await AppKV.open()).getString('parent_pin') ?? '';
  static Future<void> setPin(String v) async => (await AppKV.open()).setString('parent_pin', v);

  /// Minutes per day, 0 = no limit.
  static Future<int> limitMin() async => int.tryParse((await AppKV.open()).getString('parent_limit') ?? '') ?? 0;
  static Future<void> setLimitMin(int m) async => (await AppKV.open()).setString('parent_limit', '$m');

  static Future<int> usedSec() async => int.tryParse((await AppKV.open()).getString('used_${_day()}') ?? '') ?? 0;
  static Future<void> setUsedSec(int s) async => (await AppKV.open()).setString('used_${_day()}', '$s');

  /// Extra minutes a parent granted today.
  static Future<int> extraMin() async => int.tryParse((await AppKV.open()).getString('extra_${_day()}') ?? '') ?? 0;
  static Future<void> addExtra(int m) async => (await AppKV.open()).setString('extra_${_day()}', '${await extraMin() + m}');
}

/// Counts the minutes the app is open each day and locks the app when the daily limit is reached.
class UsageGuard {
  UsageGuard._();

  static final ValueNotifier<bool> locked = ValueNotifier<bool>(false);
  static Timer? _timer;
  static int _used = 0;
  static int _limit = 0;
  static int _extra = 0;

  static Future<void> start() async {
    if (_timer != null) return;
    await reload();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final st = WidgetsBinding.instance.lifecycleState;
      if (st != null && st != AppLifecycleState.resumed) return;
      _used += 15;
      await ParentPrefs.setUsedSec(_used);
      _check();
    });
  }

  static Future<void> reload() async {
    _used = await ParentPrefs.usedSec();
    _limit = await ParentPrefs.limitMin();
    _extra = await ParentPrefs.extraMin();
    _check();
  }

  static int get usedMin => _used ~/ 60;
  static int get leftMin => _limit == 0 ? -1 : ((_limit + _extra) * 60 - _used).clamp(0, 1 << 30) ~/ 60;

  static void _check() {
    final over = _limit > 0 && _used >= (_limit + _extra) * 60;
    if (locked.value != over) locked.value = over;
  }
}

/// Full-screen "time is up" cover. A parent types the PIN to give 15 more minutes.
class TimeUpOverlay extends StatefulWidget {
  const TimeUpOverlay({super.key});
  @override
  State<TimeUpOverlay> createState() => _TimeUpOverlayState();
}

class _TimeUpOverlayState extends State<TimeUpOverlay> {
  String _entry = '';
  String _msg = '';

  Future<void> _unlock() async {
    final pin = await ParentPrefs.pin();
    if (pin.isEmpty || _entry == pin) {
      await ParentPrefs.addExtra(15);
      await UsageGuard.reload();
      setState(() {
        _entry = '';
        _msg = '';
      });
    } else {
      setState(() {
        _entry = '';
        _msg = 'Wrong PIN';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    return Material(
      color: const Color(0xF2080A1E),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24 * s),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('\u{1F634}', style: TextStyle(fontSize: 72 * s)),
            Text("Time's up for today!", style: kidText(34 * s), textAlign: TextAlign.center),
            SizedBox(height: 6 * s),
            Text('Great learning. See you tomorrow!', style: kidText(18 * s, w: FontWeight.w600), textAlign: TextAlign.center),
            SizedBox(height: 22 * s),
            Text('Parent: enter PIN for 15 more minutes', style: kidText(14 * s, w: FontWeight.w600)),
            SizedBox(height: 8 * s),
            PinPad(value: _entry, s: s, onChanged: (String v) => setState(() => _entry = v), onSubmit: _unlock),
            if (_msg.isNotEmpty) Text(_msg, style: kidText(14 * s, c: const Color(0xFFFF8A80))),
          ]),
        ),
      ),
    );
  }
}

class ParentZoneScreen extends StatefulWidget {
  const ParentZoneScreen({super.key});
  @override
  State<ParentZoneScreen> createState() => _ParentZoneScreenState();
}

class _ParentZoneScreenState extends State<ParentZoneScreen> {
  bool _checking = true;
  bool _ok = false;
  String _pin = '';
  String _entry = '';
  String _msg = '';
  int _limit = 0;
  String _tvCode = '';
  final List<({Player p, int stars, int streak, Map<String, int> today, List<int> week})> _rep = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _pin = await ParentPrefs.pin();
    _limit = await ParentPrefs.limitMin();
    if (!mounted) return;
    setState(() => _checking = false);
  }

  Future<void> _loadReport() async {
    _rep.clear();
    for (final p in PlayerStore.players) {
      final r = await Progress.summary(p.id);
      _rep.add((p: p, stars: r.stars, streak: r.streak, today: r.today, week: r.week));
    }
    await UsageGuard.reload();
    _tvCode = await TvLink.tvCode();
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final t = _entry;
    if (_pin.isEmpty) {
      if (t.length != 4 || int.tryParse(t) == null) {
        setState(() => _msg = 'Use exactly 4 digits.');
        return;
      }
      await ParentPrefs.setPin(t);
      _pin = t;
    } else if (t != _pin) {
      setState(() {
        _entry = '';
        _msg = 'Wrong PIN';
      });
      return;
    }
    _entry = '';
    _ok = true;
    _msg = '';
    await _loadReport();
  }

  Future<void> _setLimit(int m) async {
    await ParentPrefs.setLimitMin(m);
    await UsageGuard.reload();
    setState(() => _limit = m);
  }

  Widget _bars(double s, List<int> week) {
    final mx = week.fold<int>(1, (int a, int b) => b > a ? b : a);
    final now = DateTime.now();
    const names = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SizedBox(
      height: 90 * s,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < week.length; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('${week[i]}', style: kidText(11 * s, w: FontWeight.w600)),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 4 * s),
                height: (4 + 50 * week[i] / mx) * s,
                decoration: BoxDecoration(color: i == week.length - 1 ? const Color(0xFFFFB84D) : const Color(0xFF35D0BA), borderRadius: BorderRadius.circular(6)),
              ),
              Text(names[now.subtract(Duration(days: week.length - 1 - i)).weekday - 1], style: kidText(11 * s, w: FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }

  Widget _card(double s, Widget child) => Container(
        margin: EdgeInsets.only(bottom: 12 * s),
        padding: EdgeInsets.all(14 * s),
        decoration: BoxDecoration(color: const Color(0xFF181B3A), borderRadius: BorderRadius.circular(20 * s)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final s = uiScale(context);
    if (_checking) return ScreenFrame(title: '\u{1F512} Parent Zone', body: const Center(child: CircularProgressIndicator(color: Colors.white)));
    if (!_ok) {
      return ScreenFrame(
        title: '\u{1F512} Parent Zone',
        body: Center(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_pin.isEmpty ? 'Choose a 4 digit PIN' : 'Enter your PIN', style: kidText(24 * s)),
              SizedBox(height: 12 * s),
              PinPad(value: _entry, s: s, onChanged: (String v) => setState(() => _entry = v), onSubmit: _submit),
              if (_msg.isNotEmpty) Padding(padding: EdgeInsets.only(top: 6 * s), child: Text(_msg, style: kidText(16 * s, c: const Color(0xFFFF8A80)))),
            ]),
          ),
        ),
      );
    }
    const modes = <String, String>{'spell': 'Spelling', 'math': 'Maths', 'quiz': 'Quiz', 'learn': 'Learn'};
    return ScreenFrame(
      title: '\u{1F512} Parent Zone',
      body: ListView(
        padding: EdgeInsets.fromLTRB(12 * s, 0, 12 * s, 24 * s),
        children: [
          _card(
            s,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Daily play time', style: kidText(20 * s)),
              SizedBox(height: 4 * s),
              Text(
                _limit == 0 ? 'No limit. Used today: ${UsageGuard.usedMin} min.' : 'Limit $_limit min. Used today: ${UsageGuard.usedMin} min, ${UsageGuard.leftMin} min left.',
                style: kidText(15 * s, w: FontWeight.w600),
              ),
              SizedBox(height: 8 * s),
              Wrap(spacing: 8 * s, children: [
                for (final m in const <int>[0, 20, 30, 45, 60, 90])
                  ChoiceChip(label: Text(m == 0 ? 'No limit' : '$m min'), selected: _limit == m, onSelected: (_) => _setLimit(m)),
              ]),
            ]),
          ),
          _card(
            s,
            Row(children: [
              Expanded(child: Text('TV code for sending from the phone: $_tvCode\nType it on the phone the first time you press Send to TV.', style: kidText(15 * s, w: FontWeight.w600))),
            ]),
          ),
          _card(
            s,
            Row(children: [
              Expanded(child: Text('Recently deleted items can be restored for ${Bin.days} days.', style: kidText(15 * s, w: FontWeight.w600))),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const BinScreen())),
                icon: const Icon(Icons.restore_from_trash_rounded),
                label: const Text('Open'),
              ),
            ]),
          ),
          for (final r in _rep)
            _card(
              s,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(r.p.emoji, style: TextStyle(fontSize: 36 * s)),
                  SizedBox(width: 10 * s),
                  Expanded(child: Text(r.p.name, style: kidText(22 * s))),
                  Text('\u{1F525} ${r.streak}   ⭐ ${r.stars}', style: kidText(16 * s)),
                ]),
                SizedBox(height: 8 * s),
                Text(
                  'Today: ${modes.entries.map((e) => '${e.value} ${r.today[e.key] ?? 0}').join('  •  ')}',
                  style: kidText(14 * s, w: FontWeight.w600),
                ),
                SizedBox(height: 10 * s),
                Text('Answers in the last 7 days', style: kidText(12 * s, c: const Color(0xFFA9ADDB))),
                SizedBox(height: 4 * s),
                _bars(s, r.week),
              ]),
            ),
        ],
      ),
    );
  }
}

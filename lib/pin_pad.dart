import 'package:flutter/material.dart';
import 'kids_ui.dart';

/// A number pad that works with the TV remote (arrow keys + OK) and with touch.
/// No system keyboard is used, so focus never gets lost.
class PinPad extends StatelessWidget {
  final String value;
  final int length;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final double s;
  final bool autofocus;

  const PinPad({super.key, required this.value, required this.onChanged, required this.onSubmit, required this.s, this.length = 4, this.autofocus = true});

  Widget _key(String label, VoidCallback onTap, {bool first = false, Color color = const Color(0xFF2B2F66), IconData? icon}) {
    return Padding(
      padding: EdgeInsets.all(4 * s),
      child: TVFocusable(
        autofocus: first && autofocus,
        scale: 1.08,
        debounceMs: 120,
        onPressed: onTap,
        builder: (BuildContext context, bool focused) => Container(
          width: 62 * s,
          height: 48 * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16 * s),
            border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 3),
          ),
          child: icon != null ? Icon(icon, color: Colors.white, size: 24 * s) : Text(label, style: kidText(24 * s)),
        ),
      ),
    );
  }

  void _add(String d) {
    if (value.length < length) onChanged('$value$d');
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < length; i++)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 6 * s),
            width: 18 * s,
            height: 18 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < value.length ? const Color(0xFFFFB84D) : Colors.transparent,
              border: Border.all(color: Colors.white70, width: 2),
            ),
          ),
      ]),
      SizedBox(height: 10 * s),
      for (final row in const <List<String>>[
        <String>['1', '2', '3'],
        <String>['4', '5', '6'],
        <String>['7', '8', '9'],
      ])
        Row(mainAxisSize: MainAxisSize.min, children: [for (final d in row) _key(d, () => _add(d), first: d == '1')]),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _key('', () {
          if (value.isNotEmpty) onChanged(value.substring(0, value.length - 1));
        }, icon: Icons.backspace_rounded),
        _key('0', () => _add('0')),
        _key('', onSubmit, icon: Icons.check_rounded, color: const Color(0xFF35D0BA)),
      ]),
    ]);
  }
}

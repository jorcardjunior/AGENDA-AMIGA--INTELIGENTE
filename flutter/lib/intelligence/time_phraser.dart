/// Converts an HH:MM time string into natural, spoken Portuguese.
library;

class TimePhraser {
  static const List<String> _hourWords = [
    'zero', 'uma', 'duas', 'três', 'quatro', 'cinco', 'seis', 'sete',
    'oito', 'nove', 'dez', 'onze', 'doze',
  ];

  /// 13h -> "uma da tarde", 21:30 -> "nove e meia da noite", 12:00 -> "meio-dia".
  static String speak(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;

    if (h == 0 && m == 0) return 'meia-noite';
    if (h == 12 && m == 0) return 'meio-dia';

    final period = _period(h);
    final hourWord = _hourWord(h, m);

    if (m == 0) {
      return '$hourWord $period'.trim();
    }

    final minuteWord = _minuteWord(m);
    return '$hourWord e $minuteWord $period'.trim();
  }

  static String _period(int h) {
    if (h >= 5 && h < 12) return 'da manhã';
    if (h >= 12 && h < 18) return 'da tarde';
    if (h >= 18 || h < 5) return 'da noite';
    return '';
  }

  static String _hourWord(int h, int m) {
    // For minutes > 0, spoken hours use "uma/duas..." (12-hour clock).
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return _hourWords[hour12];
  }

  static String _minuteWord(int m) {
    if (m == 15) return 'quinze';
    if (m == 30) return 'meia';
    if (m == 45) return 'quarenta e cinco';
    if (m == 5) return 'cinco';
    if (m == 10) return 'dez';
    if (m == 20) return 'vinte';
    if (m == 25) return 'vinte e cinco';
    if (m == 35) return 'trinta e cinco';
    if (m == 40) return 'quarenta';
    if (m == 50) return 'cinquenta';
    if (m < 20) {
      const under = [
        'zero', 'um', 'dois', 'três', 'quatro', 'cinco', 'seis', 'sete',
        'oito', 'nove', 'dez', 'onze', 'doze', 'treze', 'catorze',
        'quinze', 'dezesseis', 'dezessete', 'dezoito', 'dezenove',
      ];
      return under[m];
    }
    // Generic fallback for uncommon minute values.
    final tens = m ~/ 10;
    final ones = m % 10;
    const tensWords = ['', 'dez', 'vinte', 'trinta', 'quarenta', 'cinquenta'];
    if (ones == 0) return tensWords[tens];
    return '${tensWords[tens]} e ${_minuteWord(ones)}';
  }
}
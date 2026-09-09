class ParsedCommand {
  final String title;
  final String date; // YYYY-MM-DD
  final String time; // HH:MM
  final String recurrence;
  final String category;
  final String priority;
  final String rawText;

  /// Day of month (1..31) when the user says "todo dia N" (monthly).
  final int? recurrenceDayOfMonth;

  /// Specific days of the week (1=Segunda .. 7=Domingo), e.g. [1, 2, 3, 4, 5] for Mon-Fri.
  final List<int>? recurrenceDaysOfWeek;

  /// Optional end date (YYYY-MM-DD) for limited duration recurrences.
  final String? recurrenceEndDate;

  /// Set when the user asked for an advance reminder: "me lembre N dias antes".
  final int? reminderDaysBefore;

  ParsedCommand({
    required this.title,
    required this.date,
    required this.time,
    required this.recurrence,
    required this.category,
    required this.priority,
    required this.rawText,
    this.recurrenceDayOfMonth,
    this.recurrenceDaysOfWeek,
    this.recurrenceEndDate,
    this.reminderDaysBefore,
  });
}

class NaturalCommandParser {
  static const List<String> categories = [
    'Saúde/Remédio',
    'Consulta',
    'Família',
    'Casa',
    'Outros',
  ];

  /// Parses a natural-language command. [now] is injectable for deterministic tests.
  ParsedCommand parse(String text, {DateTime? now}) {
    final original = text;
    var lower = text.toLowerCase();
    final base = now ?? DateTime.now();

    // 1. Category and priority detection
    String category = 'Outros';
    String priority = 'Média';

    if (lower.contains('remedio') ||
        lower.contains('remédio') ||
        lower.contains('medicamento') ||
        lower.contains('comprimido') ||
        lower.contains('gota') ||
        lower.contains('vitamina') ||
        lower.contains('pressão') ||
        lower.contains('pressao') ||
        lower.contains('dor') ||
        lower.contains('saude') ||
        lower.contains('insulina') ||
        lower.contains('colírio') ||
        lower.contains('colirio')) {
      category = 'Saúde/Remédio';
      priority = 'Alta';
    } else if (lower.contains('consulta') ||
        lower.contains('medico') ||
        lower.contains('médico') ||
        lower.contains('doutor') ||
        lower.contains('exame') ||
        lower.contains('hospital') ||
        lower.contains('dentista') ||
        lower.contains('terapia') ||
        lower.contains('fisioterapia')) {
      category = 'Consulta';
      priority = 'Alta';
    } else if (lower.contains('aniversario') ||
        lower.contains('aniversário') ||
        lower.contains('show') ||
        lower.contains('reuniao') ||
        lower.contains('reunião') ||
        lower.contains('filho') ||
        lower.contains('filha') ||
        lower.contains('neto') ||
        lower.contains('familia') ||
        lower.contains('família') ||
        lower.contains('esposa') ||
        lower.contains('marido') ||
        lower.contains('mae') ||
        lower.contains('mãe') ||
        lower.contains('pai') ||
        lower.contains('irmao') ||
        lower.contains('irmão') ||
        lower.contains('curso') ||
        lower.contains('aula') ||
        lower.contains('escola') ||
        lower.contains('academia') ||
        lower.contains('treino')) {
      category = 'Família';
      priority = 'Média';
    } else if (lower.contains('casa') ||
        lower.contains('agua') ||
        lower.contains('água') ||
        lower.contains('luz') ||
        lower.contains('comida') ||
        lower.contains('mercado') ||
        lower.contains('compras') ||
        lower.contains('contas') ||
        lower.contains('boleto') ||
        lower.contains('pagamento') ||
        lower.contains('banco') ||
        lower.contains('aluguel') ||
        lower.contains('limpeza') ||
        lower.contains('faxina')) {
      category = 'Casa';
      priority = 'Média';
    }

    // 2. Advance reminder ("me lembre 3 dias antes").
    int? reminderDaysBefore;
    final rmb = RegExp(r'(\d+)\s*(?:dias?|dia)\s+(?:antes|de\s+antecedencia|de\s+antecedência)')
        .firstMatch(lower);
    if (rmb != null) {
      final n = int.parse(rmb.group(1)!);
      if (n > 0 && n <= 365) reminderDaysBefore = n;
    }

    // 3. Duration / End Date limit ("por 1 semana", "durante 1 mês", "por 3 semanas")
    String? recurrenceEndDate;
    final durWeek = RegExp(r'(?:por|durante)\s+(\d+|uma|duas|três|tres)\s+semanas?').firstMatch(lower);
    if (durWeek != null) {
      int weeks = 1;
      final rawNum = durWeek.group(1)!;
      if (rawNum == 'uma' || rawNum == '1') {
        weeks = 1;
      } else if (rawNum == 'duas' || rawNum == '2') {
        weeks = 2;
      } else if (rawNum == 'três' || rawNum == 'tres' || rawNum == '3') {
        weeks = 3;
      } else {
        weeks = int.tryParse(rawNum) ?? 1;
      }
      final end = base.add(Duration(days: weeks * 7));
      recurrenceEndDate = '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    }
    final durMonth = RegExp(r'(?:por|durante)\s+(\d+|um|dois|três|tres)\s+m[eê]s(?:es)?').firstMatch(lower);
    if (durMonth != null) {
      int months = 1;
      final rawNum = durMonth.group(1)!;
      if (rawNum == 'um' || rawNum == '1') {
        months = 1;
      } else if (rawNum == 'dois' || rawNum == '2') {
        months = 2;
      } else if (rawNum == 'três' || rawNum == 'tres' || rawNum == '3') {
        months = 3;
      } else {
        months = int.tryParse(rawNum) ?? 1;
      }
      final end = DateTime(base.year, base.month + months, base.day);
      recurrenceEndDate = '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    }

    // 4. Weekday set detection ("segunda a sexta", "segunda e quinta", "finais de semana", etc.)
    List<int>? daysOfWeek = _extractDaysOfWeek(lower);

    // 5. Recurrence detection
    String recurrence = 'Único';
    int? dom;

    if (lower.contains('de hora em hora') || lower.contains('a cada hora')) {
      recurrence = 'De hora em hora';
    } else if (lower.contains('a cada 2 horas') || lower.contains('a cada duas horas')) {
      recurrence = 'A cada 2 horas';
    } else if (lower.contains('a cada 3 horas') || lower.contains('a cada três horas')) {
      recurrence = 'A cada 3 horas';
    } else if (lower.contains('a cada 3 dias') || lower.contains('a cada três dias')) {
      recurrence = 'A cada 3 dias';
    } else if (lower.contains('a cada 2 dias') || lower.contains('a cada dois dias') || lower.contains('dia sim dia não') || lower.contains('dia sim dia nao') || lower.contains('dias alternados')) {
      recurrence = 'A cada 2 dias';
    } else if (lower.contains('todo dia') && _hasMonthlyDay(lower) != null) {
      dom = _hasMonthlyDay(lower);
      recurrence = 'Mensal';
    } else if (daysOfWeek != null && daysOfWeek.isNotEmpty) {
      // Multiple days specified or explicit recurring weekdays pattern
      if (daysOfWeek.length == 7) {
        recurrence = 'Todos os dias';
        daysOfWeek = null;
      } else if (daysOfWeek.length == 1 &&
          !lower.contains('toda') &&
          !lower.contains('todas') &&
          !lower.contains('sempre') &&
          !lower.contains('semanal') &&
          !lower.contains('toda semana')) {
        // Single specific weekday without "toda/sempre" -> one-shot
        recurrence = 'Único';
      } else if (daysOfWeek.length == 1) {
        recurrence = 'Semanal';
      } else {
        recurrence = 'Dias da semana';
      }
    } else if (lower.contains('toda semana') || lower.contains('semanal')) {
      recurrence = 'Semanal';
    } else if (lower.contains('todos os dias') ||
        lower.contains('diariamente') ||
        lower.contains('todo dia') ||
        lower.contains('todo santo dia')) {
      recurrence = 'Todos os dias';
    }

    // 6. Resolve date + time.
    final target = _resolve(lower, base, recurrence, dom, daysOfWeek);

    return ParsedCommand(
      title: original.isEmpty ? '' : original[0].toUpperCase() + original.substring(1),
      date:
          '${target.year.toString().padLeft(4, '0')}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}',
      time:
          '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}',
      recurrence: recurrence,
      category: category,
      priority: priority,
      rawText: original,
      recurrenceDayOfMonth: dom,
      recurrenceDaysOfWeek: daysOfWeek,
      recurrenceEndDate: recurrenceEndDate,
      reminderDaysBefore: reminderDaysBefore,
    );
  }

  // ---------------------------------------------------------------------------
  // Date/Time resolution
  // ---------------------------------------------------------------------------
  DateTime _resolve(String lower, DateTime now, String recurrence, int? dom, List<int>? daysOfWeek) {
    final time = _extractTime(lower, now);

    // A) Relative timelines ("daqui 3 minutos", "daqui a 2 horas", "daqui a 5 dias").
    final relMinutes = _relativeMinutes(lower);
    final relHours = _relativeHours(lower);
    final relDays = _relativeDays(lower);

    if (relMinutes != null || relHours != null) {
      return now.add(Duration(minutes: relMinutes ?? 0, hours: relHours ?? 0));
    }
    if (relDays != null) {
      final d = now.add(Duration(days: relDays));
      if (time.hasExplicit) {
        return DateTime(d.year, d.month, d.day, time.hour, time.minute);
      }
      return d;
    }
    if (lower.contains('agora') || lower.contains('já') || lower.contains('ja')) {
      return DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);
    }

    // B) Multiple days of week ("de segunda a sexta", "segunda e quinta", etc.)
    if (daysOfWeek != null && daysOfWeek.isNotEmpty) {
      return _findNextMatchingWeekday(now, daysOfWeek, time);
    }

    // C) Monthly recurrence anchored to a specific day of the month.
    if (recurrence == 'Mensal' && dom != null) {
      return _nextMonthDay(now, dom, time);
    }

    // D) Absolute day of month, optionally with named month / "do mês que vem".
    final absDay = _absoluteDayOfMonth(lower);
    final month = _specificMonth(lower);
    final nextMonth = lower.contains('mes que vem') || lower.contains('mês que vem');
    if (absDay != null) {
      if (nextMonth) {
        final first = DateTime(now.year, now.month + 1, 1);
        return DateTime(first.year, first.month,
            _clampDay(absDay, first.year, first.month), time.hour, time.minute);
      }
      if (month != null) {
        var candidate = DateTime(now.year, month,
            _clampDay(absDay, now.year, month), time.hour, time.minute);
        if (!candidate.isAfter(now)) {
          candidate = DateTime(now.year + 1, month,
              _clampDay(absDay, now.year + 1, month), time.hour, time.minute);
        }
        return candidate;
      }
      return _nextMonthDay(now, absDay, time);
    }

    // E) Named month without a day -> first future day of that month.
    if (month != null) {
      var candidate = DateTime(now.year, month, 1, time.hour, time.minute);
      if (!candidate.isAfter(now)) {
        candidate = DateTime(now.year + 1, month, 1, time.hour, time.minute);
      }
      return candidate;
    }

    // F) Weekday names ("segunda", "quarta-feira", ...).
    final weekday = _weekday(lower);
    if (weekday != null) {
      var candidate = _nextWeekday(now, weekday, time);
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 7));
      }
      return candidate;
    }

    // G) "hoje" / "amanhã" / "depois de amanhã".
    int dayOffset = 0;
    if (RegExp(r'depois de amanh[ãa]').hasMatch(lower)) {
      dayOffset = 2;
    } else if (RegExp(r'\bamanh[ãa]\b').hasMatch(lower)) {
      dayOffset = 1;
    }

    var candidate = DateTime(now.year, now.month, now.day, time.hour, time.minute)
        .add(Duration(days: dayOffset));
    if (time.hasExplicit && !candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    if (!time.hasExplicit && dayOffset == 0 && !candidate.isAfter(now)) {
      candidate = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    }
    return candidate;
  }

  /// Finds the first future occurrence from [now] matching any of the days in [daysOfWeek].
  /// E.g., if today is Wednesday (3) at 10:00, and [daysOfWeek] is [1, 4] (Mon, Thu) with time 09:00:
  /// - Wednesday is not in list
  /// - Thursday (4) is tomorrow -> returns Thursday at 09:00!
  /// If today is Thursday (4) at 08:00 with time 09:00 -> returns Today (Thu) at 09:00!
  /// If today is Thursday (4) at 10:00 with time 09:00 -> returns next Monday (1) at 09:00!
  DateTime _findNextMatchingWeekday(DateTime now, List<int> daysOfWeek, TimeSpec time) {
    final h = time.hasExplicit ? time.hour : 9;
    final m = time.hasExplicit ? time.minute : 0;

    for (int offset = 0; offset < 14; offset++) {
      final candDate = now.add(Duration(days: offset));
      if (daysOfWeek.contains(candDate.weekday)) {
        final candTime = DateTime(candDate.year, candDate.month, candDate.day, h, m);
        if (candTime.isAfter(now)) {
          return candTime;
        }
      }
    }
    // Fallback
    return DateTime(now.year, now.month, now.day, h, m).add(const Duration(days: 1));
  }

  DateTime _nextMonthDay(DateTime now, int day, TimeSpec time) {
    final h = time.hasExplicit ? time.hour : 9;
    final m = time.hasExplicit ? time.minute : 0;
    final todayCand = DateTime(
        now.year, now.month, _clampDay(day, now.year, now.month), h, m);
    if (todayCand.isAfter(now)) return todayCand;
    final nextY = now.month == 12 ? now.year + 1 : now.year;
    final nextM = now.month == 12 ? 1 : now.month + 1;
    return DateTime(nextY, nextM, _clampDay(day, nextY, nextM), h, m);
  }

  DateTime _nextWeekday(DateTime now, int weekday, TimeSpec time) {
    final diff = (weekday - now.weekday) % 7;
    final d = now.add(Duration(days: diff));
    return DateTime(d.year, d.month, d.day, time.hour, time.minute);
  }

  int _clampDay(int day, int y, int m) => day.clamp(1, _daysInMonth(y, m));

  int _daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

  // ---------------------------------------------------------------------------
  // Weekday extraction and Range detection
  // ---------------------------------------------------------------------------
  List<int>? _extractDaysOfWeek(String lower) {
    // 1. "segunda a sexta" / "segunda até sexta" / "segunda feira a sexta feira"
    final rangeRegex = RegExp(
        r'(?:de\s+)?(segunda|terça|terca|quarta|quinta|sexta|sábado|sabado|domingo)(?:-feira)?\s+(?:a|à|ate|até)\s+(segunda|terça|terca|quarta|quinta|sexta|sábado|sabado|domingo)(?:-feira)?');
    final rm = rangeRegex.firstMatch(lower);
    if (rm != null) {
      final start = _dayNameToWeekday(rm.group(1)!);
      final end = _dayNameToWeekday(rm.group(2)!);
      if (start != null && end != null) {
        final days = <int>[];
        if (start <= end) {
          for (int d = start; d <= end; d++) {
            days.add(d);
          }
        } else {
          // Wrap around (e.g. sexta a domingo = 5, 6, 7; ou sexta a terca = 5, 6, 7, 1, 2)
          for (int d = start; d <= 7; d++) {
            days.add(d);
          }
          for (int d = 1; d <= end; d++) {
            days.add(d);
          }
        }
        return days;
      }
    }

    // 2. "finais de semana" / "final de semana" / "fim de semana" / "fins de semana"
    if (lower.contains('fim de semana') ||
        lower.contains('finais de semana') ||
        lower.contains('final de semana') ||
        lower.contains('fins de semana')) {
      return [6, 7]; // Sábado (6) e Domingo (7)
    }

    // 3. "dias de semana" / "dias úteis" / "dias uteis"
    if (lower.contains('dias de semana') ||
        lower.contains('dias úteis') ||
        lower.contains('dias uteis')) {
      return [1, 2, 3, 4, 5]; // Segunda a Sexta
    }

    // 4. Multiple discrete weekdays: "segunda e quinta", "terça, quinta e sábado", "toda segunda e quarta"
    final foundDays = <int>{};
    const dayTokens = [
      ['domingo', 7],
      ['segunda', 1],
      ['terça', 2],
      ['terca', 2],
      ['quarta', 3],
      ['quinta', 4],
      ['sexta', 5],
      ['sábado', 6],
      ['sabado', 6],
    ];

    for (final token in dayTokens) {
      final name = token[0] as String;
      final val = token[1] as int;
      if (RegExp('\\b$name(?:-feira)?\\b').hasMatch(lower)) {
        foundDays.add(val);
      }
    }

    if (foundDays.length >= 2) {
      final sorted = foundDays.toList()..sort();
      return sorted;
    } else if (foundDays.length == 1) {
      // Se tiver "toda", "todas", "sempre", retorna como lista de 1 dia
      if (lower.contains('toda') ||
          lower.contains('todas') ||
          lower.contains('sempre') ||
          lower.contains('semanal')) {
        return foundDays.toList();
      }
    }

    return null;
  }

  int? _dayNameToWeekday(String name) {
    if (name.startsWith('seg')) return 1;
    if (name.startsWith('ter')) return 2;
    if (name.startsWith('qua')) return 3;
    if (name.startsWith('qui')) return 4;
    if (name.startsWith('sex')) return 5;
    if (name.startsWith('sáb') || name.startsWith('sab')) return 6;
    if (name.startsWith('dom')) return 7;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  int? _hasMonthlyDay(String lower) {
    final m = RegExp(r'todo\s+dia\s+(\d{1,2})').firstMatch(lower);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      if (n >= 1 && n <= 31) return n;
    }
    final mm = RegExp(r'dia\s+(\d{1,2})\s+de\s+cada\s+m[eê]s').firstMatch(lower);
    if (mm != null) {
      final n = int.parse(mm.group(1)!);
      if (n >= 1 && n <= 31) return n;
    }
    return null;
  }

  int? _absoluteDayOfMonth(String lower) {
    final m = RegExp(r'\bdia\s+(\d{1,2})\b').firstMatch(lower);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      if (n >= 1 && n <= 31) return n;
    }
    return null;
  }

  int? _specificMonth(String lower) {
    const months = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];
    for (var i = 0; i < months.length; i++) {
      if (lower.contains(months[i])) return i + 1;
    }
    const abbrs = {'jan': 1, 'fev': 2, 'mar': 3, 'abr': 4, 'ago': 8, 'set': 9, 'out': 10, 'nov': 11, 'dez': 12};
    for (final e in abbrs.entries) {
      if (RegExp('\\b${RegExp.escape(e.key)}\\b').hasMatch(lower)) return e.value;
    }
    return null;
  }

  int? _weekday(String lower) {
    const days = [
      ['domingo', 7],
      ['segunda', 1],
      ['terça', 2],
      ['terca', 2],
      ['quarta', 3],
      ['quinta', 4],
      ['sexta', 5],
      ['sábado', 6],
      ['sabado', 6],
    ];
    for (final pair in days) {
      if (RegExp('\\b${RegExp.escape(pair[0] as String)}(?:-feira)?\\b').hasMatch(lower)) {
        return pair[1] as int;
      }
    }
    return null;
  }

  int? _relativeMinutes(String lower) {
    if (RegExp(r'daqui\s+a\s+meia\s+hora|daqui\s+meia\s+hora').hasMatch(lower)) return 30;
    final mm = RegExp(r'daqui\s+(?:a\s+)?(\d+)\s*(?:min(?:utos?)?|minuto)')
        .firstMatch(lower);
    if (mm != null) {
      final n = int.parse(mm.group(1)!);
      if (n >= 1 && n <= 1440) return n;
    }
    return null;
  }

  int? _relativeHours(String lower) {
    final hh = RegExp(r'daqui\s+(?:a\s+)?(\d+)\s*(?:h|hora|horas)\b').firstMatch(lower);
    if (hh != null) {
      final n = int.parse(hh.group(1)!);
      if (n >= 1 && n <= 72) return n;
    }
    return null;
  }

  int? _relativeDays(String lower) {
    final d = RegExp(r'daqui\s+(?:a\s+)?(\d+)\s*dias?\b').firstMatch(lower);
    if (d != null) {
      final n = int.parse(d.group(1)!);
      if (n >= 1 && n <= 365) return n;
    }
    if (lower.contains('daqui a uma semana') || lower.contains('daqui a 1 semana')) return 7;
    return null;
  }

  TimeSpec _extractTime(String lower, DateTime now) {
    // Remove day-of-month/time-distance phrases so their digits are not
    // misread as clock times ("todo dia 10" must not become "10:00").
    var s = lower
        .replaceAll(RegExp(r'todo\s+dia\s+\d{1,2}'), ' ')
        .replaceAll(RegExp(r'dia\s+\d{1,2}\s+de\s+cada\s+m[eê]s'), ' ')
        .replaceAll(RegExp(r'dia\s+\d{1,2}\s+de\s+[a-zãçáéíóú]+'), ' ')
        .replaceAll(RegExp(r'dia\s+\d{1,2}'), ' ')
        .replaceAll(RegExp(r'\d+\s*dias?\s+(?:antes|de\s*antecedencia|de\s*antecedência)'), ' ')
        .replaceAll(RegExp(r'me\s+lembre|v[aá]\s+lembrar|lembre'), ' ')
        .replaceAll(RegExp(r'daqui\s+(?:a\s+)?\d+\s*(?:min(?:utos?)?|h(?:oras?)?|dias?)\b'), ' ');

    if (RegExp(r'\bmeio[-\s]?dia\b').hasMatch(s)) {
      return TimeSpec(hour: 12, minute: 0, hasExplicit: true);
    }
    if (RegExp(r'\bmeia[-\s]?noite\b').hasMatch(s)) {
      return TimeSpec(hour: 0, minute: 0, hasExplicit: true);
    }

    final m = RegExp(
            r'(?:às|as|ao|a)?\s?(\d{1,2})(?::(\d{2}))?\s*(?:h(?:oras?)?)?\b')
        .firstMatch(s);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final min = m.group(2) != null ? int.parse(m.group(2)!) : 0;
      if (h >= 0 && h <= 23 && min <= 59) {
        var hour = h;
        if (hour < 12 && RegExp(r'\bnoite\b').hasMatch(s)) {
          hour += 12;
        } else if (hour >= 1 && hour < 12 && RegExp(r'\btarde\b').hasMatch(s)) {
          hour += 12;
        } else if (hour == 12 && RegExp(r'\bmanh[ãa]\b').hasMatch(s)) {
          hour = 0;
        }
        return TimeSpec(hour: hour, minute: min, hasExplicit: true);
      }
    }
    return TimeSpec(hour: now.hour, minute: now.minute, hasExplicit: false);
  }
}

class TimeSpec {
  final int hour;
  final int minute;
  final bool hasExplicit;

  TimeSpec({required this.hour, required this.minute, required this.hasExplicit});
}

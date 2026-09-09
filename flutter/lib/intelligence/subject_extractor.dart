/// Extracts the "core subject" of a commitment title so the announcer can
/// paraphrase it naturally instead of repeating the raw user text.
library;

class ExtractedSubject {
  /// Clean noun phrase, pronouns normalized (minha -> sua).
  final String text;

  /// True when the subject refers to a person (mãe, filho, esposa...) so the
  /// announcer can add a personalized (and caring) follow-up.
  final bool involvesPerson;

  const ExtractedSubject(this.text, this.involvesPerson);
}

class SubjectExtractor {
  /// Recurrence phrases that make a reminder "daily/weekly" but carry no
  /// subject value word-by-word.
  static const List<String> _recurrencePhrases = [
    'todos os dias', 'todo dia', 'todo santo dia', 'diariamente',
    'toda manhã', 'todas as manhãs', 'todas as noites', 'todo dia de manhã',
    'pela manhã', 'à noite', 'à tarde', 'de manhã', 'da manhã', 'da tarde',
    'de madrugada', 'da noite', 'durante o dia', 'durante a noite',
    'de hora em hora', 'a cada hora', 'a cada 2 horas', 'a cada duas horas',
    'a cada 3 horas', 'a cada três horas', 'a cada 4 horas',
    'de duas em duas horas', 'de três em três horas', 'de 4 em 4 horas',
    'uma vez por semana', 'todas as semanas', 'semanal', 'semanalmente',
    'toda semana', 'a cada 3 dias', 'a cada três dias', 'de três em três dias',
    'a cada 7 dias', 'todo sábado', 'todo domingo', 'toda segunda-feira',
    'toda terça-feira', 'toda quarta-feira', 'toda quinta-feira',
    'toda sexta-feira', 'toda segunda', 'toda terça', 'toda quarta',
    'toda quinta', 'toda sexta', 'toda semana', 'quando acordar',
  ];

  /// Preamble/instructions words people put before the actual subject.
  static const List<String> _preamblePhrases = [
    'quero', 'gostaria', 'preciso', 'preciso de lembrete para', 'me lembre de',
    'me lembre para', 'lembre de', 'lembrar de', 'lembrar de agendar',
    'não posso esquecer', 'nao posso esquecer', 'não quero esquecer',
    'anote para mim', 'me avise sobre', 'me avise para', 'me ajude',
    'marca para mim', 'coloca na agenda', 'agenda para mim', 'agenda',
    'vou precisar', 'tenho que', 'eu preciso de',
    'me faça um favor de lembrar', 'favor lembrar', 'lembrete de',
  ];

  /// Second-person normalization so the app talks TO the user, not repeats
  /// what they said in first person ("minha mãe" -> "sua mãe").
  static const Map<String, String> _personMap = {
    'minha': 'sua', 'meu': 'seu', 'minhas': 'suas', 'meus': 'seus',
    'comigo': 'com você', 'para mim': 'para você', 'a mim': 'a você',
  };

  /// Name patterns that denote a person (for personalized caring follow-ups).
  static const List<String> _personKeywords = [
    'mãe', 'mae', 'mamãe', 'mamae', 'pai', 'avó', 'avô', 'avo', 'av,',
    'filho', 'filha', 'neto', 'neta', 'primo', 'prima', 'tio', 'tia',
    'sobrinho', 'sobrinha', 'esposa', 'marido', 'companheiro', 'companheira',
    'na minha', 'namorada', 'namorado', 'genro', 'nora', 'cunhado', 'cunhada',
  ];

  /// Removes time expressions ("as 7", "às 14h30", "7 da manhã").
  static final RegExp _timePattern = RegExp(
    r'\b(?:às|as|a)\s*\d{1,2}(?::\d{2})?\s*(?:h\b|horas?\b|hrs?\b)?'
    r'|\b\d{1,2}\s*(?:h\b|horas?\b|hr(?:a|as)?\b)\s*'
    r'(?:da manha|da manhã|da tarde|da noite|de madrugada|da madrugada)?'
    r'|\b\d{1,2}:\d{2}\b',
    caseSensitive: false,
  );

  static final RegExp _numberTimePattern = RegExp(
    r'^\d{1,2}\s*(?:h|horas|hora|hrs|hr)?\s*$',
    caseSensitive: false,
  );

  /// Extracts the meaningful core of `title`.
  static ExtractedSubject extract(String title) {
    if (title.trim().isEmpty) {
      return const ExtractedSubject('seu compromisso', false);
    }

    var lower = title.toLowerCase().trim();

    // 1. Remove preambles (repeatedly, some phrases contain others).
    for (final p in _preamblePhrases) {
      lower = lower.replaceAll(
          RegExp('\\b${RegExp.escape(p)}\\b', caseSensitive: false), ' ');
    }

    // 2. Remove repetition/time phrases.
    for (final r in _recurrencePhrases) {
      lower = lower.replaceAll(
          RegExp('\\b${RegExp.escape(r)}\\b', caseSensitive: false), ' ');
    }
    lower = lower.replaceAll(_timePattern, ' ');

    // 3. Fallback: if only a bare number+period remains (pure time), drop it.
    lower = lower.replaceAll(_numberTimePattern, ' ');

    // 4. Clean leftover " as " / " as" connectors and collapse whitespace.
    lower = lower
        .replaceAll(RegExp(r'\b(?:às|as)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 5. Normalize first-person -> second-person references.
    var normalized = lower;
    _personMap.forEach((from, to) {
      normalized = normalized.replaceAll(
          RegExp('\\b${RegExp.escape(from)}\\b', caseSensitive: false), to);
    });

    // 6. Capitalise the first letter of the sentence.
    var text = _capitalize(normalized);

    final involvesPerson = _personKeywords
        .any((k) => text.toLowerCase().contains(k));

    if (text.isEmpty) {
      return const ExtractedSubject('seu compromisso', false);
    }
    return ExtractedSubject(text, involvesPerson);
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
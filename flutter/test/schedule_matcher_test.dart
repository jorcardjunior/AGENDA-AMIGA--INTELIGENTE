import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_amiga_flutter/models/commitment.dart';
import 'package:agenda_amiga_flutter/scheduling/schedule_matcher.dart';

Commitment _c({
  required String date,
  String time = '09:00',
  String? recurrence,
  int? recurrenceDayOfMonth,
  List<int>? recurrenceDaysOfWeek,
  String? recurrenceEndDate,
}) {
  return Commitment(
    id: '1',
    title: 'Teste',
    date: date,
    time: time,
    priority: 'Média',
    category: 'Outros',
    completed: false,
    recurrence: recurrence,
    recurrenceDayOfMonth: recurrenceDayOfMonth,
    recurrenceDaysOfWeek: recurrenceDaysOfWeek,
    recurrenceEndDate: recurrenceEndDate,
  );
}

void main() {
  group('ScheduleMatcher.occursOn', () {
    test('compromisso único só na data marcada', () {
      final c = _c(date: '2026-09-10');
      expect(ScheduleMatcher.occursOn(c, '2026-09-10'), isTrue);
      expect(ScheduleMatcher.occursOn(c, '2026-09-11'), isFalse);
    });

    test('dias da semana — Segunda a Sexta [1, 2, 3, 4, 5]', () {
      final c = _c(
        date: '2026-09-08', // terça (2)
        recurrence: 'Dias da semana',
        recurrenceDaysOfWeek: [1, 2, 3, 4, 5],
      );
      expect(ScheduleMatcher.occursOn(c, '2026-09-08'), isTrue); // Terça
      expect(ScheduleMatcher.occursOn(c, '2026-09-09'), isTrue); // Quarta
      expect(ScheduleMatcher.occursOn(c, '2026-09-10'), isTrue); // Quinta
      expect(ScheduleMatcher.occursOn(c, '2026-09-11'), isTrue); // Sexta
      expect(ScheduleMatcher.occursOn(c, '2026-09-12'), isFalse); // Sábado
      expect(ScheduleMatcher.occursOn(c, '2026-09-13'), isFalse); // Domingo
      expect(ScheduleMatcher.occursOn(c, '2026-09-14'), isTrue); // Segunda
    });

    test('dias da semana — Segunda e Quinta [1, 4]', () {
      final c = _c(
        date: '2026-09-08',
        recurrence: 'Dias da semana',
        recurrenceDaysOfWeek: [1, 4],
      );
      expect(ScheduleMatcher.occursOn(c, '2026-09-08'), isFalse); // Terça
      expect(ScheduleMatcher.occursOn(c, '2026-09-10'), isTrue); // Quinta (4)
      expect(ScheduleMatcher.occursOn(c, '2026-09-14'), isTrue); // Segunda (1)
    });

    test('recurrenceEndDate — não dispara após data limite', () {
      final c = _c(
        date: '2026-09-08',
        recurrence: 'Dias da semana',
        recurrenceDaysOfWeek: [1, 2, 3, 4, 5],
        recurrenceEndDate: '2026-09-11', // Sexta
      );
      expect(ScheduleMatcher.occursOn(c, '2026-09-11'), isTrue); // Dentro do limite
      expect(ScheduleMatcher.occursOn(c, '2026-09-14'), isFalse); // Após o limite
    });

    test('mensal no dia 10 de todo mês', () {
      final c = _c(date: '2026-09-10', recurrence: 'Mensal', recurrenceDayOfMonth: 10);
      expect(ScheduleMatcher.occursOn(c, '2026-09-10'), isTrue);
      expect(ScheduleMatcher.occursOn(c, '2026-10-10'), isTrue);
      expect(ScheduleMatcher.occursOn(c, '2026-10-09'), isFalse);
    });

    test('mensal dia 31 clampa em fevereiro', () {
      final c = _c(date: '2026-01-31', recurrence: 'Mensal', recurrenceDayOfMonth: 31);
      expect(ScheduleMatcher.occursOn(c, '2026-02-28'), isTrue);
      expect(ScheduleMatcher.occursOn(c, '2026-03-31'), isTrue);
    });

    test('mensal usa o dia da data se field ausente', () {
      final c = _c(date: '2026-09-05', recurrence: 'Mensal');
      expect(ScheduleMatcher.occursOn(c, '2026-10-05'), isTrue);
    });

    test('semanal mesmo dia da semana', () {
      final c = _c(date: '2026-09-01', recurrence: 'Semanal'); // terça
      expect(ScheduleMatcher.occursOn(c, '2026-09-08'), isTrue); // terça
      expect(ScheduleMatcher.occursOn(c, '2026-09-09'), isFalse); // quarta
    });

    test('todos os dias em qualquer data', () {
      final c = _c(date: '2026-09-01', recurrence: 'Todos os dias');
      expect(ScheduleMatcher.occursOn(c, '2026-09-01'), isTrue);
      expect(ScheduleMatcher.occursOn(c, '2026-12-31'), isTrue);
    });

    test('a cada 3 dias respeita o intervalo', () {
      final c = _c(date: '2026-09-01', recurrence: 'A cada 3 dias');
      expect(ScheduleMatcher.occursOn(c, '2026-09-01'), isTrue);
      expect(ScheduleMatcher.occursOn(c, '2026-09-04'), isTrue);
      expect(ScheduleMatcher.occursOn(c, '2026-09-05'), isFalse);
      expect(ScheduleMatcher.occursOn(c, '2026-08-30'), isFalse); // antes do início
    });
  });

  group('ScheduleMatcher.matchesTime', () {
    test('hora e minuto idênticos', () {
      final c = _c(date: '2026-09-08', time: '07:00');
      expect(ScheduleMatcher.matchesTime(c, DateTime(2026, 9, 8, 7, 0, 30)), isTrue);
      expect(ScheduleMatcher.matchesTime(c, DateTime(2026, 9, 8, 7, 1)), isFalse);
    });
  });
}

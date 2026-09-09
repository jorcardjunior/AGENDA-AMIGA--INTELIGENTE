import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_amiga_flutter/parser/natural_command_parser.dart';

/// Tuesday, 2026-09-08 10:00 — deterministic anchor for all timeline tests.
/// 2026-09-08 is a Tuesday (2).
/// 2026-09-09 is a Wednesday (3).
/// 2026-09-10 is a Thursday (4).
/// 2026-09-11 is a Friday (5).
/// 2026-09-12 is a Saturday (6).
/// 2026-09-13 is a Sunday (7).
/// 2026-09-14 is a Monday (1).
final _now = DateTime(2026, 9, 8, 10, 0);

void main() {
  group('NaturalCommandParser — relative timelines', () {
    test('daqui 3 minutos (sem "a") — bug que não disparava o alarme', () {
      final r = NaturalCommandParser().parse('tomar água daqui 3 minutos', now: _now);
      expect(r.date, '2026-09-08');
      expect(r.time, '10:03');
      expect(r.recurrence, 'Único');
    });

    test('daqui a 30 minutos', () {
      final r = NaturalCommandParser().parse('beber remédio daqui a 30 minutos', now: _now);
      expect(r.date, '2026-09-08');
      expect(r.time, '10:30');
    });

    test('daqui a 2 horas', () {
      final r = NaturalCommandParser().parse('reunião daqui a 2 horas', now: _now);
      expect(r.date, '2026-09-08');
      expect(r.time, '12:00');
    });

    test('daqui a 3 dias', () {
      final r = NaturalCommandParser().parse('consulta daqui a 3 dias', now: _now);
      expect(r.date, '2026-09-11');
      expect(r.time, '10:00');
    });
  });

  group('NaturalCommandParser — dias da semana complexos e intervalos', () {
    test('ir ao curso de segunda a sexta às 9 (hoje terça 10:00) -> próxima ocorrência é quarta', () {
      final r = NaturalCommandParser().parse('ir ao curso de segunda a sexta às 9', now: _now);
      expect(r.recurrence, 'Dias da semana');
      expect(r.recurrenceDaysOfWeek, [1, 2, 3, 4, 5]);
      expect(r.date, '2026-09-09'); // Quarta-feira
      expect(r.time, '09:00');
    });

    test('ir ao curso de segunda a sexta às 14 (hoje terça 10:00) -> hoje ainda dá tempo (terça às 14)', () {
      final r = NaturalCommandParser().parse('ir ao curso de segunda a sexta às 14', now: _now);
      expect(r.recurrence, 'Dias da semana');
      expect(r.recurrenceDaysOfWeek, [1, 2, 3, 4, 5]);
      expect(r.date, '2026-09-08'); // Terça-feira (hoje)
      expect(r.time, '14:00');
    });

    test('reunião na segunda e na quinta às 9 (hoje terça 10:00) -> próxima é quinta (10/09)', () {
      final r = NaturalCommandParser().parse('reunião na segunda e na quinta às 9', now: _now);
      expect(r.recurrence, 'Dias da semana');
      expect(r.recurrenceDaysOfWeek, [1, 4]);
      expect(r.date, '2026-09-10'); // Quinta-feira
      expect(r.time, '09:00');
    });

    test('toda segunda e quarta às 8 -> dias [1, 3], próxima quarta (09/09)', () {
      final r = NaturalCommandParser().parse('toda segunda e quarta às 8', now: _now);
      expect(r.recurrence, 'Dias da semana');
      expect(r.recurrenceDaysOfWeek, [1, 3]);
      expect(r.date, '2026-09-09'); // Quarta
      expect(r.time, '08:00');
    });

    test('todos os finais de semana às 10 -> dias [6, 7], próximo sábado (12/09)', () {
      final r = NaturalCommandParser().parse('caminhar todo fim de semana às 10', now: _now);
      expect(r.recurrence, 'Dias da semana');
      expect(r.recurrenceDaysOfWeek, [6, 7]);
      expect(r.date, '2026-09-12'); // Sábado
      expect(r.time, '10:00');
    });

    test('de segunda a sabado às 7 -> dias [1, 2, 3, 4, 5, 6]', () {
      final r = NaturalCommandParser().parse('trabalho de segunda a sabado às 7', now: _now);
      expect(r.recurrence, 'Dias da semana');
      expect(r.recurrenceDaysOfWeek, [1, 2, 3, 4, 5, 6]);
      expect(r.date, '2026-09-09'); // Quarta às 7h
      expect(r.time, '07:00');
    });

    test('dia sim dia não / dias alternados -> A cada 2 dias', () {
      final r = NaturalCommandParser().parse('tomar vitamina dia sim dia não às 8', now: _now);
      expect(r.recurrence, 'A cada 2 dias');
      expect(r.time, '08:00');
    });

    test('durante 1 semana -> define recurrenceEndDate', () {
      final r = NaturalCommandParser().parse('tomar antibiótico de segunda a sexta às 8 por 1 semana', now: _now);
      expect(r.recurrence, 'Dias da semana');
      expect(r.recurrenceEndDate, '2026-09-15');
    });
  });

  group('NaturalCommandParser — mensal "todo dia N"', () {
    test('todo dia 10 às 9 — próxima ocorrência este mês', () {
      final r = NaturalCommandParser()
          .parse('reunião da empresa todo dia 10 às 9', now: _now);
      expect(r.recurrence, 'Mensal');
      expect(r.recurrenceDayOfMonth, 10);
      expect(r.date, '2026-09-10');
      expect(r.time, '09:00');
    });

    test('todo dia 10 sem horário — padrão 09:00', () {
      final r = NaturalCommandParser()
          .parse('reunião da empresa todo dia 10', now: _now);
      expect(r.recurrence, 'Mensal');
      expect(r.recurrenceDayOfMonth, 10);
      expect(r.date, '2026-09-10');
      expect(r.time, '09:00');
    });

    test('todo dia 10 quando o dia deste mês já passou — vai para o mês que vem', () {
      final late = DateTime(2026, 9, 10, 20, 0);
      final r = NaturalCommandParser()
          .parse('reunião da empresa todo dia 10 às 9', now: late);
      expect(r.recurrence, 'Mensal');
      expect(r.recurrenceDayOfMonth, 10);
      expect(r.date, '2026-10-10');
      expect(r.time, '09:00');
    });

    test('todo dia 31 não vira dia 30 em mês curto no futuro', () {
      final r =
          NaturalCommandParser().parse('pagamento todo dia 31', now: _now);
      expect(r.recurrence, 'Mensal');
      expect(r.recurrenceDayOfMonth, 31);
      expect(r.date, '2026-09-30'); // setembro tem 30 dias
    });
  });

  group('NaturalCommandParser — dia absoluto', () {
    test('dia 20 do mês que vem', () {
      final r = NaturalCommandParser()
          .parse('reunião dia 20 do mês que vem', now: _now);
      expect(r.date, '2026-10-20');
    });

    test('dia 20 de julho — próximo ano se já passou', () {
      final r = NaturalCommandParser()
          .parse('consulta médico dia 20 de julho', now: _now);
      expect(r.date, '2027-07-20');
    });

    test('dia 15 simples — próxima ocorrência', () {
      final r = NaturalCommandParser().parse('encontro dia 15', now: _now);
      expect(r.date, '2026-09-15');
      expect(r.time, '09:00');
    });
  });

  group('NaturalCommandParser — dias e turnos', () {
    test('amanhã às 7', () {
      final r = NaturalCommandParser()
          .parse('tomar remédio amanhã às 7', now: _now);
      expect(r.date, '2026-09-09');
      expect(r.time, '07:00');
    });

    test('segunda-feira às 9 — próxima segunda', () {
      final r = NaturalCommandParser()
          .parse('reunião na segunda-feira às 9', now: _now);
      expect(r.date, '2026-09-14');
      expect(r.time, '09:00');
    });

    test('sexta às 10', () {
      final r =
          NaturalCommandParser().parse('show sexta às 10', now: _now);
      expect(r.date, '2026-09-11');
      expect(r.time, '10:00');
    });

    test('depois de amanhã', () {
      final r = NaturalCommandParser()
          .parse('pagamento depois de amanhã às 8', now: _now);
      expect(r.date, '2026-09-10');
      expect(r.time, '08:00');
    });

    test('todos os dias às 8 — recorrência diária', () {
      final r = NaturalCommandParser()
          .parse('levar neto no médico todos os dias às 8', now: _now);
      expect(r.recurrence, 'Todos os dias');
      expect(r.time, '08:00');
    });

    test('toda segunda-feira às 9 — recorrência semanal', () {
      final r = NaturalCommandParser()
          .parse('reunião toda segunda-feira às 9', now: _now);
      expect(r.recurrence, 'Semanal');
      expect(r.time, '09:00');
    });

    test('segunda-feira simples — só a próxima, sem repetição', () {
      final r = NaturalCommandParser()
          .parse('reunião na segunda-feira às 9', now: _now);
      expect(r.recurrence, 'Único');
      expect(r.date, '2026-09-14');
    });

    test('horário passado no mesmo dia — muda para amanhã', () {
      final r = NaturalCommandParser()
          .parse('consulta às 9', now: _now);
      expect(r.date, '2026-09-09');
      expect(r.time, '09:00');
    });

    test('14:30 hoje', () {
      final r = NaturalCommandParser().parse('consulta às 14:30', now: _now);
      expect(r.date, '2026-09-08');
      expect(r.time, '14:30');
    });

    test('sem horário — padrão agora + 1h', () {
      final r = NaturalCommandParser().parse('beber água', now: _now);
      expect(r.date, '2026-09-08');
      expect(r.time, '11:00');
    });
  });

  group('NaturalCommandParser — lembrete antecipado', () {
    test('me lembre 3 dias antes', () {
      final r = NaturalCommandParser()
          .parse('consulta me lembre 3 dias antes', now: _now);
      expect(r.reminderDaysBefore, 3);
    });

    test('aviso 1 dia antes da data', () {
      final r = NaturalCommandParser()
          .parse('aniversário aviso 1 dia antes', now: _now);
      expect(r.reminderDaysBefore, 1);
      expect(r.date, '2026-09-08');
    });

    test('lembrete não altera o mês da recorrência mensal', () {
      final r = NaturalCommandParser()
          .parse('reunião da empresa todo dia 10', now: _now);
      expect(r.recurrence, 'Mensal');
      expect(r.date, '2026-09-10');
    });
  });

  group('NaturalCommandParser — categorias', () {
    test('remédio → Saúde/Remédio alta prioridade', () {
      final r = NaturalCommandParser()
          .parse('tomar o remédio da tireoide', now: _now);
      expect(r.category, 'Saúde/Remédio');
      expect(r.priority, 'Alta');
    });

    test('consulta → Consulta', () {
      final r = NaturalCommandParser().parse('consulta com o médico', now: _now);
      expect(r.category, 'Consulta');
    });
  });
}

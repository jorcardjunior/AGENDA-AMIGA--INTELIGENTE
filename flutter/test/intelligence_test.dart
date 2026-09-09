import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_amiga_flutter/intelligence/intent_classifier.dart';
import 'package:agenda_amiga_flutter/intelligence/subject_extractor.dart';
import 'package:agenda_amiga_flutter/intelligence/time_phraser.dart';
import 'package:agenda_amiga_flutter/intelligence/message_composer.dart';
import 'package:agenda_amiga_flutter/intelligence/announcer.dart';
import 'package:agenda_amiga_flutter/models/commitment.dart';

Commitment _c({
  required String title,
  String time = '07:00',
  String priority = 'Média',
  String recurrence = 'Único',
}) {
  return Commitment(
    id: '1',
    title: title,
    date: '2026-01-01',
    time: time,
    priority: priority,
    category: 'Outros',
    completed: false,
    recurrence: recurrence,
  );
}

void main() {
  group('IntentClassifier', () {
    test('medication high gravity', () {
      final r = IntentClassifier.classify('tomar remédio da tireoide todos os dias as 6');
      expect(r.intent, CommitmentIntent.medication);
      expect(r.gravity, SpeechGravity.high);
    });

    test('wake up', () {
      final r = IntentClassifier.classify('acordar todos os dias as 7 da manhã');
      expect(r.intent, CommitmentIntent.wakeUp);
    });

    test('call mom', () {
      final r = IntentClassifier.classify('ligar para minha mãe as 10');
      expect(r.intent, CommitmentIntent.call);
    });

    test('appointment', () {
      final r = IntentClassifier.classify('consulta no cardiologista as 14');
      expect(r.intent, CommitmentIntent.healthAppointment);
      expect(r.gravity, SpeechGravity.high);
    });

    test('payment', () {
      final r = IntentClassifier.classify('pagar conta de luz as 9');
      expect(r.intent, CommitmentIntent.payment);
    });

    test('generic insurance', () {
      final r = IntentClassifier.classify('postar documento as 10');
      expect(r.intent, CommitmentIntent.generic);
    });
  });

  group('SubjectExtractor', () {
    test('removes time + recurrence from medication', () {
      final s = SubjectExtractor.extract('tomar remédio da tireoide todos os dias as 6');
      expect(s.text, contains('remédio da tireoide'));
      expect(s.text.toLowerCase(), isNot(contains('todos os dias')));
      expect(s.text.toLowerCase(), isNot(contains('as 6')));
    });

    test('normalizes minha -> sua for mom', () {
      final s = SubjectExtractor.extract('ligar para minha mãe as 10');
      expect(s.text, 'Ligar para sua mãe');
      expect(s.involvesPerson, isTrue);
    });

    test('normalizes meu -> seu for son', () {
      final s = SubjectExtractor.extract('ligar para meu filho as 18');
      expect(s.text, 'Ligar para seu filho');
    });

    test('removes acordar template from wake', () {
      final s = SubjectExtractor.extract('acordar todos os dias as 7 da manhã');
      expect(s.text.toLowerCase(), isNot(contains('7')));
    });
  });

  group('TimePhraser', () {
    test('morning hours', () {
      expect(TimePhraser.speak('06:00'), 'seis da manhã');
      expect(TimePhraser.speak('07:00'), 'sete da manhã');
    });
    test('midday', () {
      expect(TimePhraser.speak('12:00'), 'meio-dia');
    });
    test('afternoon with minutes', () {
      expect(TimePhraser.speak('14:00'), 'duas da tarde');
      expect(TimePhraser.speak('21:30'), 'nove e meia da noite');
    });
    test('midnight', () {
      expect(TimePhraser.speak('00:00'), 'meia-noite');
    });
  });

  group('Announcer', () {
    test('medication alarm speaks hour, subject and God blessing', () {
      final text = Announcer.alarm(_c(
        title: 'tomar remédio da tireoide todos os dias as 6',
        time: '06:00',
      ));
      expect(text.toLowerCase(), contains('seis da manhã'));
      expect(text.toLowerCase(), contains('remédio da tireoide'));
      expect(text.toLowerCase(), contains('deus'));
    });

    test('daily wake does not repeat the full user text', () {
      final text = Announcer.alarm(_c(
        title: 'acordar todos os dias as 7 da manhã',
        time: '07:00',
      ));
      expect(text.toLowerCase(), isNot(contains('acordar todos os dias')));
      expect(text.toLowerCase(), contains('deus'));
    });

    test('call mom is personalized', () {
      final text = Announcer.alarm(_c(
        title: 'ligar para minha mãe as 10',
        time: '10:00',
      ));
      expect(text.toLowerCase(), contains('sua mãe'));
      expect(text.toLowerCase(), isNot(contains('minha mãe')));
      expect(text.toLowerCase(), contains('deus'));
    });

    test('confirmation is warm', () {
      final text = Announcer.confirmation(_c(title: 'tomar remédio de pressão as 8', time: '08:00'));
      expect(text.toLowerCase(), contains('remédio'));
      expect(text.toLowerCase(), contains('deus'));
    });

    test('briefing line is short and useful', () {
      final text = Announcer.briefingLine(
          _c(title: 'consulta no cardiologista as 14', time: '14:00'));
      expect(text.toLowerCase(), contains('cardiologista'));
    });
  });

  group('MessageComposer rotation', () {
    test('rotates closings so it never repeats verbatim', () {
      final texts = [
        for (var i = 0; i < 6; i++)
          MessageComposer.compose(
            _c(title: 'tomar remédio de pressão as 8', time: '08:00'),
            context: SpeechContext.alarm,
          ).text,
      ];
      expect(texts.toSet().length, greaterThan(2));
    });
  });
}
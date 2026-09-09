/// Builds warm, topic-aware announcements with rotating biblical closings.
/// Everything runs on-device (no network) and never repeats the user's raw
/// text word for word.
library;

import '../models/commitment.dart';
import 'intent_classifier.dart';
import 'subject_extractor.dart';
import 'time_phraser.dart';

class SmartMessage {
  /// The exact text the TTS should read aloud.
  final String text;

  /// Short subject used by compact modes (briefing/confirmation).
  final String subject;

  const SmartMessage(this.text, this.subject);
}

/// Where the message will be spoken, influences greeting + pacing.
enum SpeechContext { alarm, confirmation, briefing }

class MessageComposer {
  /// Rotating index so repeated daily alarms don't repeat the same phrase
  /// every day.
  static final Map<CommitmentIntent, int> _rotation = {};

  /// Greeting by time of day (turns repeated daily alarms natural and humane).
  static String greetingForHour(int hour) {
    if (hour >= 0 && hour < 5) return 'Boa madrugada.';
    if (hour < 12) return 'Bom dia!';
    if (hour < 18) return 'Boa tarde!';
    return 'Boa noite!';
  }

  /// Greeting that also carries the spoken hour ("são sete da manhã").
  static String timeGreeting(int hour, String time) {
    final period = greetingForHour(hour);
    final spoken = TimePhraser.speak(time);
    if (hour == 12 && time == '12:00') return '$period É meio-dia.';
    if (hour == 0 && time == '00:00') return '$period É meia-noite.';
    return '$period São $spoken.';
  }

  /// Composes the announcement shown as an alarm.
  static SmartMessage compose(Commitment c, {SpeechContext context = SpeechContext.alarm}) {
    final result = IntentClassifier.classify(c.title);
    final subject = SubjectExtractor.extract(c.title);

    final slot = _nextSlot(result.intent);
    String text;

    // Greeting always based on NOW (current device time), not on the
    // scheduled time.  E.g. if user hears the confirmation at 8 PM, it says
    // "Boa noite!" even though the appointment is for 9 AM tomorrow.
    final nowHour = DateTime.now().hour;

    switch (context) {
      case SpeechContext.confirmation:
        text = _confirmation(result, subject, c, nowHour);
      case SpeechContext.briefing:
        text = _briefing(result, subject, c, nowHour);
      case SpeechContext.alarm:
        // When the alarm fires it IS the current moment, so nowHour = alarm hour.
        text = _alarm(result, subject, c, nowHour, slot);
    }

    return SmartMessage(text, subject.text);
  }

  // ---- Alarm --------------------------------------------------------------

  static String _alarm(IntentResult r, ExtractedSubject s, Commitment c,
      int hour, int slot) {
    final greeting = timeGreeting(hour, c.time);
    final action = _actionPhrase(r.intent, s.text, slot);
    final closing = _closing(r, s, slot);
    return '$greeting $action $closing';
  }

  static String _actionPhrase(CommitmentIntent intent, String subject, int slot) {
    final s = subject.isEmpty ? 'seu compromisso' : subject;
    switch (intent) {
      case CommitmentIntent.wakeUp:
        return _pick([
          'Hora de acordar e começar o dia com energia!',
          'Acorde com a mente leve, o corpo pronto e o sorriso aberto.',
          'Está na hora de levantar. Mais um dia lindo aguarda você.',
          'Desperte com gratidão. O dia é seu hoje.',
        ], slot);
      case CommitmentIntent.medication:
        return _pick([
          'Está na hora de tomar o $s.',
          'Esse é o momento do seu $s.',
          'Atenção: hora do seu $s.',
          'Lembre-se de tomar o $s.',
        ], slot);
      case CommitmentIntent.healthAppointment:
        return _pick([
          'Está na hora do seu compromisso de saúde: $s.',
          'Agora é o momento da sua $s.',
          'Chegou a hora: $s.',
          'Não esqueça o seu cuidado com a saúde: $s.',
        ], slot);
      case CommitmentIntent.call:
        return _pick([
          'Está na hora de $s.',
          'Agora é o momento de $s.',
          'Chegou a hora de $s.',
          'Não esqueça de $s.',
        ], slot);
      case CommitmentIntent.family:
        return _pick([
          'Hoje é um dia especial: $s.',
          'Está na hora de $s.',
          'Agora é a hora de $s.',
          'Se lembre com carinho: $s.',
        ], slot);
      case CommitmentIntent.payment:
        return _pick([
          'Lembrete importante: está na hora de $s.',
          'Não deixe para depois: $s.',
          'Agora é o melhor momento para $s.',
          'Organize agora: $s.',
        ], slot);
      case CommitmentIntent.work:
        return _pick([
          'Chegou a hora da sua atividade profissional: $s.',
          'Está na hora de $s.',
          'Esse é o seu momento de $s.',
          'Foco no que é importante: $s.',
        ], slot);
      case CommitmentIntent.home:
        return _pick([
          'Está na hora de cuidar do seu cantinho: $s.',
          'Hora de $s.',
          'Agora é um bom momento para $s.',
          'Sua casa agradece: $s.',
        ], slot);
      case CommitmentIntent.errand:
        return _pick([
          'Está na hora de $s.',
          'Hora de resolver: $s.',
          'Esse é o momento de $s.',
          'Vá com calma e resolva: $s.',
        ], slot);
      case CommitmentIntent.meal:
        return _pick([
          'Está na hora da sua refeição: $s.',
          'Hora de cuidar da alimentação: $s.',
          'Lembre-se de se alimentar bem: $s.',
          'Esse é um ótimo momento para $s.',
        ], slot);
      case CommitmentIntent.spiritual:
        return _pick([
          'Este é um momento especial de fé: $s.',
          'Está na hora de $s.',
          'Agora é o momento da sua conexão com Deus: $s.',
          'Seu coração pede: $s.',
        ], slot);
      case CommitmentIntent.study:
        return _pick([
          'Está na hora de estudar: $s.',
          'Hora dos estudos: $s.',
          'Esse é o momento de $s.',
          'Seus estudos aguardam: $s.',
        ], slot);
      case CommitmentIntent.exercise:
        return _pick([
          'Está na hora de movimentar o corpo: $s.',
          'Hora da sua atividade física: $s.',
          'Sua saúde agradece: $s.',
          'Agora é o momento de $s.',
        ], slot);
      case CommitmentIntent.rest:
        return _pick([
          'Chegou a sua hora de pausa: $s.',
          'Está na hora de descansar: $s.',
          'Você merece esse momento: $s.',
          'Agora é hora de $s.',
        ], slot);
      case CommitmentIntent.generic:
        return _pick([
          'Está na hora do seu compromisso: $s.',
          'Agora é o momento: $s.',
          'Chegou a sua hora de $s.',
          'Seu compromisso: $s.',
        ], slot);
    }
  }

  /// Biblical + caring closing, chosen per intent and rotated by `slot`.
  static String _closing(IntentResult r, ExtractedSubject s, int slot) {
    switch (r.intent) {
      case CommitmentIntent.medication:
        return _pick([
          'Que Deus cuide de você e da sua saúde.',
          'Deus te fortaleça, e não se esqueça: sua saúde vem primeiro.',
          'Que a cura de Deus esteja em você hoje.',
          'Deus é o teu bem maior, cuide do teu corpo.',
          'Que Deus dê equilíbrio e restauração pra você.',
        ], slot);
      case CommitmentIntent.healthAppointment:
        return _pick([
          'Que Deus guie o seu atendimento e abençoe sua vida.',
          'Deus está com você nessa consulta, tudo vai dar certo.',
          'Que a paz de Deus acalme o seu coração.',
          'Confia em Deus e siga com esperança.',
        ], slot);
      case CommitmentIntent.wakeUp:
        return _pick([
          'Que este dia seja abençoado por Deus.',
          'Que a luz de Deus ilumine todos os seus passos hoje.',
          'Bom dia com a bênção de Deus.',
          'Que a fé em Deus esteja no seu coração o dia inteiro.',
          'Que Deus cubra você de bênçãos neste novo dia.',
        ], slot);
      case CommitmentIntent.family:
        return _pick([
          'Que Deus abençoe a sua família e a nossa casa.',
          'Deus proteja quem você ama.',
          'Que o amor de Deus encha o coração de todos.',
          'Que a bênção de Deus una ainda mais vocês.',
        ], slot);
      case CommitmentIntent.payment:
        return _pick([
          'Deus provê, confie no cuidado dEle.',
          'Que Deus abençoe suas finanças e seu trabalho.',
          'Com fé e organização tudo se resolve, Deus está contigo.',
          'Deus é a tua provisão, não se perturbe.',
        ], slot);
      case CommitmentIntent.call:
        return _pick([
          'Que Deus abençoe essa conversa.',
          'Deus use esse momento para unir corações.',
          'Que a sua palavra leve a bênção de Deus.',
          'Deus ouça a sua voz e guie essa conversa.',
        ], slot);
      case CommitmentIntent.work:
        return _pick([
          'Deus abençoe o seu trabalho e os seus projetos.',
          'Que a sabedoria de Deus esteja em cada decisão.',
          'Deus te capacite para vencer hoje.',
          'Que o trabalho das suas mãos seja abençoado.',
        ], slot);
      case CommitmentIntent.home:
        return _pick([
          'Deus abençoe a sua casa e a sua família.',
          'Que a paz de Deus reine no seu lar.',
          'Deus cuida dos detalhes, pode confiar.',
          'Que a sua casa seja cheia de harmonia.',
        ], slot);
      case CommitmentIntent.errand:
        return _pick([
          'Deus te proteja no caminho.',
          'Que Deus te cubra de segurança.',
          'Com Deus no caminho, tudo dá certo.',
          'Que a proteção de Deus esteja com você.',
        ], slot);
      case CommitmentIntent.meal:
        return _pick([
          'Bom apetite com a bênção de Deus.',
          'Deus abençoe esse alimento e a sua saúde.',
          'Que a mesa nunca falte com a graça de Deus.',
          'Alimente-se bem e que Deus fortaleça você.',
        ], slot);
      case CommitmentIntent.spiritual:
        return _pick([
          'Que a paz do Senhor esteja com você.',
          'Que o Espírito Santo renove suas forças.',
          'Deus está contigo, sempre.',
          'Que a sua fé se renove agora.',
          'Jesus te ama, nunca se esqueça.',
        ], slot);
      case CommitmentIntent.study:
        return _pick([
          'Deus te dê sabedoria e entendimento.',
          'Que Deus ilumine os seus estudos.',
          'Foco e bênção, Deus está contigo.',
          'Que os teus estudos dêem bons frutos.',
        ], slot);
      case CommitmentIntent.exercise:
        return _pick([
          'Deus te dê energia e disposição.',
          'Movimente o corpo que Deus te deu com gratidão.',
          'Que a vitalidade de Deus te acompanhe.',
          'Cuide do templo do Espírito Santo com alegria.',
        ], slot);
      case CommitmentIntent.rest:
        return _pick([
          'Descanse na paz de Deus.',
          'Que Deus restaure as suas forças.',
          'Encontre no Senhor a sua calma.',
          'Que o seu corpo e mente encontrem descanso em Deus.',
        ], slot);
      case CommitmentIntent.generic:
        return _pick([
          'Que Deus abençoe esse momento.',
          'Deus está cuidando de você sempre.',
          'Tudo com Deus no controle.',
          'Que a graça de Deus te acompanhe.',
          'Seja abençoado em tudo o que fizer.',
        ], slot);
    }
  }

  // ---- Confirmation (right after the user schedules) ----------------------

  static String _confirmation(IntentResult r, ExtractedSubject s,
      Commitment c, int hour) {
    final t = TimePhraser.speak(c.time);
    final greeting = greetingForHour(hour);
    final action = _pick([
      'Pronto! Registrei com carinho: ${s.text}.',
      'Anotado com muita atenção: ${s.text}.',
      'Tudo certo! Fica na sua agenda: ${s.text}.',
    ], _nextSlot(r.intent));
    final when = _pick([
      'Marcado para $t.',
      'Combinado para $t.',
      'Lembrete agendado para $t.',
    ], _nextSlot(r.intent));
    final blessing = _closing(r, s, _nextSlot(r.intent));
    return '$greeting $action $when $blessing';
  }

  // ---- Morning briefing (compact, per commitment) -------------------------

  static String _briefing(IntentResult r, ExtractedSubject s, Commitment c,
      int hour) {
    final t = TimePhraser.speak(c.time);
    final action = _pick([
      'Às $t, ${_verbIfNeeded(r.intent, s.text)}.',
      '${s.text} às $t.',
      'Através do seu compromisso: ${s.text}, às $t.',
    ], _nextSlot(r.intent));
    return action;
  }

  static String _verbIfNeeded(CommitmentIntent intent, String subject) {
    // keep subject as the key item; adds a light verb for naturalness.
    switch (intent) {
      case CommitmentIntent.medication:
        return 'tomar o seu remédio (${subject.isEmpty ? 'como combinado' : subject})';
      case CommitmentIntent.wakeUp:
        return 'hora de acordar';
      case CommitmentIntent.healthAppointment:
        return 'você tem compromisso de saúde';
      default:
        return subject.isEmpty ? 'compromisso' : subject;
    }
  }

  // ---- helpers ------------------------------------------------------------

  static String _pick(List<String> options, int index) {
    return options[index % options.length];
  }

  static int _nextSlot(CommitmentIntent intent) {
    final next = (_rotation[intent] ?? 0) + 1;
    _rotation[intent] = next;
    return next;
  }
}
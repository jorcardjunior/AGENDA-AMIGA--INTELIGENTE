/// Single entry point for everything the assistant says, so all speech flows
/// through one intelligent, on-device, topic-aware system.
library;

import '../models/commitment.dart';
import '../parser/natural_command_parser.dart';
import 'message_composer.dart';
import 'subject_extractor.dart';

class Announcer {
  /// Full spoken announcement for a firing alarm.
  static String alarm(Commitment c) => MessageComposer.compose(
      c, context: SpeechContext.alarm).text;

  /// Short line used inside the alarm modal (after the big announcement).
  static String alarmModalLine(Commitment c) {
    final subject = SubjectExtractor.extract(c.title).text;
    return subject.isEmpty ? 'Atenção, horário do seu compromisso.' : 'Atenção: $subject.';
  }

  /// Confirmation right after the user schedules a commitment.
  static String confirmation(Commitment c) => MessageComposer.compose(
      c, context: SpeechContext.confirmation).text;

  /// Compact line for the morning briefing (already sorted by time).
  static String briefingLine(Commitment c) => MessageComposer.compose(
      c, context: SpeechContext.briefing).text;

  /// Confirmation before the user schedules (right after voice parsing).
  static String preConfirmation(ParsedCommand cmd) {
    final c = _fromParsed(cmd);
    return MessageComposer.compose(c, context: SpeechContext.confirmation).text;
  }

  static Commitment _fromParsed(ParsedCommand cmd) {
    return Commitment(
      id: 'pending',
      title: cmd.title,
      date: cmd.date,
      time: cmd.time,
      priority: cmd.priority,
      category: cmd.category,
      completed: false,
      recurrence: cmd.recurrence,
    );
  }
}
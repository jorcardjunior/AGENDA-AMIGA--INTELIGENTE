class Commitment {
  final String id;
  final String title;
  final String date;
  final String time;
  final String priority;
  final String category;
  final bool completed;
  final String? correctionNote;
  final String? recurrence;

  /// Day of month (1..31) for monthly recurrence, e.g. "Todo dia 10" -> 10.
  final int? recurrenceDayOfMonth;

  /// Specific days of week (1=Segunda .. 7=Domingo), e.g. [1, 2, 3, 4, 5] for "Segunda a Sexta",
  /// or [1, 4] for "Segunda e Quinta".
  final List<int>? recurrenceDaysOfWeek;

  /// Optional end date (YYYY-MM-DD) for limited recurrences ("por 1 semana", "durante 1 mês").
  final String? recurrenceEndDate;

  /// Advance reminder: ring N days before the commitment ("me lembre 3 dias antes").
  final int? reminderDaysBefore;

  Commitment({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.priority,
    required this.category,
    required this.completed,
    this.correctionNote,
    this.recurrence,
    this.recurrenceDayOfMonth,
    this.recurrenceDaysOfWeek,
    this.recurrenceEndDate,
    this.reminderDaysBefore,
  });

  Commitment copyWith({
    String? title,
    String? date,
    String? time,
    String? priority,
    String? category,
    bool? completed,
    String? correctionNote,
    String? recurrence,
    int? recurrenceDayOfMonth,
    List<int>? recurrenceDaysOfWeek,
    String? recurrenceEndDate,
    int? reminderDaysBefore,
  }) {
    return Commitment(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      completed: completed ?? this.completed,
      correctionNote: correctionNote ?? this.correctionNote,
      recurrence: recurrence ?? this.recurrence,
      recurrenceDayOfMonth: recurrenceDayOfMonth ?? this.recurrenceDayOfMonth,
      recurrenceDaysOfWeek: recurrenceDaysOfWeek ?? this.recurrenceDaysOfWeek,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'time': time,
        'priority': priority,
        'category': category,
        'completed': completed,
        'correctionNote': correctionNote,
        'recurrence': recurrence,
        'recurrenceDayOfMonth': recurrenceDayOfMonth,
        'recurrenceDaysOfWeek': recurrenceDaysOfWeek,
        'recurrenceEndDate': recurrenceEndDate,
        'reminderDaysBefore': reminderDaysBefore,
      };

  factory Commitment.fromJson(Map<String, dynamic> json) => Commitment(
        id: json['id'],
        title: json['title'],
        date: json['date'],
        time: json['time'],
        priority: json['priority'] ?? 'Média',
        category: json['category'] ?? 'Outros',
        completed: json['completed'] ?? false,
        correctionNote: json['correctionNote'],
        recurrence: json['recurrence'],
        recurrenceDayOfMonth: json['recurrenceDayOfMonth'],
        recurrenceDaysOfWeek: json['recurrenceDaysOfWeek'] != null
            ? List<int>.from(json['recurrenceDaysOfWeek'])
            : null,
        recurrenceEndDate: json['recurrenceEndDate'],
        reminderDaysBefore: json['reminderDaysBefore'],
      );
}

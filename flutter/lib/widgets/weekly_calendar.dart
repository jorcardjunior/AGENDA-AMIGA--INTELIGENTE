import 'package:flutter/material.dart';
import '../models/commitment.dart';
import '../scheduling/schedule_matcher.dart';
import '../utils/date_formatter.dart';

class WeeklyCalendar extends StatelessWidget {
  final List<Commitment> commitments;
  final String selectedDate;
  final ValueChanged<String> onSelectDate;
  final void Function(String) speakText;

  const WeeklyCalendar({
    super.key,
    required this.commitments,
    required this.selectedDate,
    required this.onSelectDate,
    required this.speakText,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday % 7));

    final weekDays = List.generate(7, (i) {
      final d = startOfWeek.add(Duration(days: i));
      return d;
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueGrey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.calendar_month, color: Colors.teal.shade700, size: 20),
              ),
              const SizedBox(width: 12),
const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Agenda Semanal',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('Selecione o dia para ver os compromissos',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: weekDays.map((d) {
              final dateStr = DateFormatter.toDateStr(d);
              final isSelected = selectedDate == dateStr;

final dayCount = commitments.where((c) {
                return ScheduleMatcher.occursOn(c, dateStr) && !c.completed;
              }).length;
              final hasCompleted = commitments
                  .any((c) => ScheduleMatcher.occursOn(c, dateStr) && c.completed);

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    onSelectDate(dateStr);
                    final naturalDate = DateFormatter.formatNaturalDate(dateStr);
                    final countMsg = dayCount == 0
                        ? 'Nenhum compromisso pendente para $naturalDate.'
                        : dayCount == 1
                            ? '1 compromisso pendente para $naturalDate.'
                            : '$dayCount compromissos pendentes para $naturalDate.';
                    speakText(countMsg);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.teal.shade600 : Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? Colors.teal.shade600 : Colors.blueGrey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormatter.shortDays[d.weekday % 7],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.teal.shade50 : Colors.blueGrey.shade500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? Colors.white : Colors.blueGrey.shade800,
                          ),
                        ),
                        Text(
                          DateFormatter.monthShortName(d),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.teal.shade50 : Colors.blueGrey.shade400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (dayCount > 0)
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Colors.teal,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (hasCompleted && dayCount == 0)
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

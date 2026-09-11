import 'package:flutter/material.dart';
import '../models/commitment.dart';
import '../scheduling/schedule_matcher.dart';
import '../utils/date_formatter.dart';

/// Calendário Mensal Inteligente com visualização de todos os dias do mês,
/// navegação anual/mensal e badges dos compromissos recorrentes e pontuais.
class MonthlyCalendar extends StatefulWidget {
  final List<Commitment> commitments;
  final String selectedDate; // YYYY-MM-DD
  final ValueChanged<String> onSelectDate;
  final void Function(String) speakText;

  const MonthlyCalendar({
    super.key,
    required this.commitments,
    required this.selectedDate,
    required this.onSelectDate,
    required this.speakText,
  });

  @override
  State<MonthlyCalendar> createState() => _MonthlyCalendarState();
}

class _MonthlyCalendarState extends State<MonthlyCalendar> {
  late DateTime _currentMonth;

  static const List<String> _weekHeaders = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  static const List<String> _monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  @override
  void initState() {
    super.initState();
    final parsed = DateTime.tryParse(widget.selectedDate) ?? DateTime.now();
    _currentMonth = DateTime(parsed.year, parsed.month, 1);
  }

  @override
  void didUpdateWidget(covariant MonthlyCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      final parsed = DateTime.tryParse(widget.selectedDate);
      if (parsed != null && (parsed.year != _currentMonth.year || parsed.month != _currentMonth.month)) {
        setState(() {
          _currentMonth = DateTime(parsed.year, parsed.month, 1);
        });
      }
    }
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    final todayStr = DateFormatter.todayStr();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
    });
    widget.onSelectDate(todayStr);
    widget.speakText('Hoje é ${DateFormatter.formatNaturalDate(todayStr)}.');
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormatter.todayStr();
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1=Seg .. 7=Dom

    // Dias vazios no início para alinhar com o dia da semana correto (Segunda = col 0)
    final leadingEmpty = firstWeekday - 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.teal.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Navegação do Mês e Ano
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.calendar_month, color: Colors.teal.shade700, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.teal.shade900,
                      ),
                    ),
                    const Text(
                      'Toque no dia para ver compromissos',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left, color: Colors.teal),
                tooltip: 'Mês anterior',
                onPressed: _prevMonth,
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  backgroundColor: Colors.teal.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _goToToday,
                child: Text('Hoje', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right, color: Colors.teal),
                tooltip: 'Próximo mês',
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cabeçalho dos dias da semana (Seg a Dom)
          Row(
            children: _weekHeaders.map((h) {
              final isWeekend = h == 'Sáb' || h == 'Dom';
              return Expanded(
                child: Center(
                  child: Text(
                    h,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isWeekend ? Colors.red.shade400 : Colors.blueGrey.shade600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 0.8),
          const SizedBox(height: 8),

          // Grid de Dias do Mês
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingEmpty + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmpty) {
                return const SizedBox.shrink();
              }

              final dayNum = index - leadingEmpty + 1;
              final dateStr =
                  '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
              final isSelected = widget.selectedDate == dateStr;
              final isToday = todayStr == dateStr;

              // Calcula compromissos deste dia usando o ScheduleMatcher inteligente
              final matching = widget.commitments.where((c) => ScheduleMatcher.occursOn(c, dateStr)).toList();
              final pendingCount = matching.where((c) => !c.completed).length;
              final completedCount = matching.where((c) => c.completed).length;
              final hasItems = matching.isNotEmpty;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    widget.onSelectDate(dateStr);
                    final natural = DateFormatter.formatNaturalDate(dateStr);
                    if (pendingCount == 0 && completedCount == 0) {
                      widget.speakText('$natural. Nenhum compromisso marcado.');
                    } else if (pendingCount > 0) {
                      widget.speakText('$natural. $pendingCount ${pendingCount == 1 ? 'compromisso pendente' : 'compromissos pendentes'}.');
                    } else {
                      widget.speakText('$natural. Todos os compromissos concluídos.');
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.teal.shade600
                          : (isToday
                              ? Colors.teal.shade50
                              : (hasItems ? const Color(0xFFF0FDF4) : Colors.white)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.teal.shade700
                            : (isToday
                                ? Colors.teal.shade400
                                : (hasItems ? Colors.teal.shade200 : Colors.blueGrey.shade100)),
                        width: isSelected || isToday ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected || isToday || hasItems ? FontWeight.w900 : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isToday ? Colors.teal.shade900 : (hasItems ? Colors.teal.shade900 : Colors.black87)),
                          ),
                        ),
                        if (hasItems) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (pendingCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : Colors.teal.shade700,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$pendingCount',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: isSelected ? Colors.teal.shade900 : Colors.white,
                                    ),
                                  ),
                                ),
                              if (completedCount > 0 && pendingCount == 0)
                                Icon(
                                  Icons.check_circle,
                                  size: 10,
                                  color: isSelected ? Colors.white : Colors.green.shade600,
                                ),
                            ],
                          ),
                        ] else
                          const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

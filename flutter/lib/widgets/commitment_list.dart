import 'package:flutter/material.dart';
import '../models/commitment.dart';
import '../scheduling/schedule_matcher.dart';
import '../utils/date_formatter.dart';

enum CommitFilter { all, pending, completed }

class CommitmentList extends StatefulWidget {
  final List<Commitment> commitments;
  final String selectedDate;
  final void Function(String) onToggleComplete;
  final void Function(String) onDelete;
  final void Function(Commitment) onEdit;
  final void Function(String) speakText;

  const CommitmentList({
    super.key,
    required this.commitments,
    required this.selectedDate,
    required this.onToggleComplete,
    required this.onDelete,
    required this.onEdit,
    required this.speakText,
  });

  @override
  State<CommitmentList> createState() => _CommitmentListState();
}

class _CommitmentListState extends State<CommitmentList> {
  CommitFilter _filter = CommitFilter.all;

  String categoryIcon(String category) {
    switch (category) {
      case 'Saúde/Remédio':
        return '💊';
      case 'Consulta':
        return '🩺';
      case 'Família':
        return '👨‍👩‍👧‍👦';
      case 'Casa':
        return '🏠';
      default:
        return '📌';
    }
  }

  Color priorityColor(String priority) {
    switch (priority) {
      case 'Alta':
        return Colors.red;
      case 'Média':
        return Colors.amber.shade800;
      default:
        return Colors.teal;
    }
  }

  String priorityLabel(String priority) {
    switch (priority) {
      case 'Alta':
        return '🔴 Alta Prioridade (Remédio/Urgente)';
      case 'Média':
        return '🟡 Média Prioridade';
      default:
        return '🟢 Baixa Prioridade';
    }
  }

  @override
  Widget build(BuildContext context) {
final filtered = widget.commitments.where((item) {
      if (!ScheduleMatcher.occursOn(item, widget.selectedDate)) {
        return false;
      }
      if (_filter == CommitFilter.pending) return !item.completed;
      if (_filter == CommitFilter.completed) return item.completed;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + filter tabs
const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Seus Compromissos e Tarefas',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  SizedBox(height: 2),
                  Text('Toque no círculo para marcar como feito ou no lápis para editar.',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _filterButton('Todos', widget.commitments.length, CommitFilter.all),
            const SizedBox(width: 6),
            _filterButton('Pendentes',
                widget.commitments.where((c) => !c.completed).length, CommitFilter.pending),
            const SizedBox(width: 6),
            _filterButton(
                'Feitos', widget.commitments.where((c) => c.completed).length, CommitFilter.completed),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blueGrey.shade200, width: 2),
            ),
            child: const Column(
              children: [
                Text('✨', style: TextStyle(fontSize: 40)),
                SizedBox(height: 8),
                Text('Nenhum compromisso por aqui!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                SizedBox(height: 4),
                Text('Use o comando de voz acima ou adicione manualmente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          )
        else
          ...filtered.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _commitmentCard(item),
              )),
      ],
    );
  }

  Widget _filterButton(String label, int count, CommitFilter f) {
    final selected = _filter == f;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = f),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.blueGrey.shade100,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                : null,
          ),
          child: Text(
            '$label ($count)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: selected ? Colors.teal.shade800 : Colors.blueGrey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _commitmentCard(Commitment item) {
    final completed = item.completed;
    final highPriority = !completed && item.priority == 'Alta';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: completed ? Colors.blueGrey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highPriority ? Colors.red.shade200 : Colors.teal.shade100,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => widget.onToggleComplete(item.id),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: completed ? Colors.teal.shade600 : Colors.blueGrey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    completed ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: completed ? Colors.white : Colors.blueGrey.shade400,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${categoryIcon(item.category)}  ',
                        style: const TextStyle(fontSize: 18)),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        decoration: completed ? TextDecoration.lineThrough : null,
                        color: completed ? Colors.blueGrey.shade300 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor(item.priority).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: priorityColor(item.priority).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        priorityLabel(item.priority),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: priorityColor(item.priority),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
_chip(Icons.calendar_today, item.date),
                        _chip(Icons.schedule, item.time),
                        if (item.recurrence != null && item.recurrence != 'Único')
                          _chip(Icons.repeat, item.recurrence!),
                        _chip(Icons.label, item.category),
                      ],
                    ),
                    if (item.correctionNote != null && item.correctionNote!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '⚠️ ${item.correctionNote}',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade800),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.volume_up, color: Colors.blueAccent),
                onPressed: () => widget.speakText(
                    'Compromisso: ${item.title}, agendado para o dia ${DateFormatter.formatNaturalDate(item.date)} às ${DateFormatter.formatNaturalTime(item.time)}. Frequência: ${item.recurrence ?? 'Único'}. Prioridade ${item.priority}.'),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.orange),
                onPressed: () => widget.onEdit(item),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => widget.onDelete(item.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.teal.shade700),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

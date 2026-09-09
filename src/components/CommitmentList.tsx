import React, { useState } from 'react';
import { Commitment } from '../types';
import { CheckCircle, Circle, Trash2, Volume2, AlertCircle, Clock, Calendar as CalendarIcon, Tag, Pencil } from 'lucide-react';

interface CommitmentListProps {
  commitments: Commitment[];
  selectedDate?: string;
  onToggleComplete: (id: string) => void;
  onDelete: (id: string) => void;
  onEdit: (commitment: Commitment) => void;
  speakText: (text: string) => void;
}

export const CommitmentList: React.FC<CommitmentListProps> = ({
  commitments,
  selectedDate,
  onToggleComplete,
  onDelete,
  onEdit,
  speakText,
}) => {
  const [filter, setFilter] = useState<'all' | 'pending' | 'completed'>('all');

  const filteredCommitments = commitments.filter((item) => {
    if (selectedDate && item.date !== selectedDate && item.recurrence !== 'Todos os dias') {
      return false;
    }
    if (filter === 'pending') return !item.completed;
    if (filter === 'completed') return item.completed;
    return true;
  });

  const getPriorityBadge = (priority: string) => {
    switch (priority) {
      case 'Alta':
        return <span className="px-3 py-1 bg-red-100 text-red-700 font-black text-xs rounded-full flex items-center gap-1 border border-red-200">🔴 Alta Prioridade (Remédio/Urgente)</span>;
      case 'Média':
        return <span className="px-3 py-1 bg-amber-100 text-amber-800 font-bold text-xs rounded-full flex items-center gap-1 border border-amber-200">🟡 Média Prioridade</span>;
      default:
        return <span className="px-3 py-1 bg-emerald-100 text-emerald-800 font-bold text-xs rounded-full flex items-center gap-1 border border-emerald-200">🟢 Baixa Prioridade</span>;
    }
  };

  const getCategoryIcon = (category: string) => {
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
  };

  return (
    <div className="space-y-6">
      
      {/* Filter Tabs & Title */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b pb-4">
        <div>
          <h3 className="text-2xl font-black text-slate-900">
            Seus Compromissos e Tarefas
          </h3>
          <p className="text-sm font-medium text-slate-500">
            Toque no círculo verde para marcar como feito ou no ícone de lápis para editar.
          </p>
        </div>

        <div className="flex items-center gap-2 bg-slate-100 p-1.5 rounded-2xl">
          <button
            onClick={() => setFilter('all')}
            className={`px-4 py-2 rounded-xl text-sm font-bold transition-all cursor-pointer ${
              filter === 'all' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Todos ({commitments.length})
          </button>
          <button
            onClick={() => setFilter('pending')}
            className={`px-4 py-2 rounded-xl text-sm font-bold transition-all cursor-pointer ${
              filter === 'pending' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Pendentes ({commitments.filter(c => !c.completed).length})
          </button>
          <button
            onClick={() => setFilter('completed')}
            className={`px-4 py-2 rounded-xl text-sm font-bold transition-all cursor-pointer ${
              filter === 'completed' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Feitos ({commitments.filter(c => c.completed).length})
          </button>
        </div>
      </div>

      {/* List */}
      {filteredCommitments.length === 0 ? (
        <div className="bg-slate-50 border-2 border-dashed border-slate-200 rounded-3xl p-12 text-center space-y-3">
          <div className="w-16 h-16 bg-emerald-100 text-emerald-600 rounded-full flex items-center justify-center mx-auto text-3xl">
            ✨
          </div>
          <h4 className="text-xl font-bold text-slate-800">Nenhum compromisso por aqui!</h4>
          <p className="text-sm text-slate-500 max-w-sm mx-auto">
            Use o comando de voz acima ou adicione/edite manualmente usando o calendário.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4">
          {filteredCommitments.map((item) => (
            <div
              key={item.id}
              className={`p-5 sm:p-6 rounded-3xl border-2 transition-all flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 shadow-sm ${
                item.completed
                  ? 'bg-slate-50 border-slate-200 opacity-75'
                  : item.priority === 'Alta'
                  ? 'bg-white border-red-200 hover:border-red-300 ring-2 ring-red-50'
                  : 'bg-white border-emerald-100 hover:border-emerald-300'
              }`}
            >
              
              {/* Left Side: Checkbox & Info */}
              <div className="flex items-start sm:items-center gap-4 flex-1">
                <button
                  onClick={() => onToggleComplete(item.id)}
                  className={`w-12 h-12 rounded-2xl flex items-center justify-center transition-all cursor-pointer shrink-0 ${
                    item.completed
                      ? 'bg-emerald-600 text-white'
                      : 'bg-slate-100 hover:bg-slate-200 text-slate-400'
                  }`}
                  aria-label={item.completed ? 'Marcar como pendente' : 'Marcar como concluído'}
                >
                  {item.completed ? <CheckCircle className="w-7 h-7" /> : <Circle className="w-7 h-7" />}
                </button>

                <div className="space-y-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-xl" title={item.category}>{getCategoryIcon(item.category)}</span>
                    <h4 className={`text-xl font-black ${item.completed ? 'line-through text-slate-400' : 'text-slate-900'}`}>
                      {item.title}
                    </h4>
                    {getPriorityBadge(item.priority)}
                  </div>

                  <div className="flex flex-wrap items-center gap-4 text-sm font-bold text-slate-500 pt-1">
                    <span className="flex items-center gap-1.5 bg-slate-100 px-3 py-1 rounded-xl">
                      <CalendarIcon className="w-4 h-4 text-emerald-600" />
                      {item.date}
                    </span>
                    <span className="flex items-center gap-1.5 bg-slate-100 px-3 py-1 rounded-xl">
                      <Clock className="w-4 h-4 text-emerald-600" />
                      {item.time}
                    </span>
                    {item.recurrence && item.recurrence !== 'Único' && (
                      <span className="flex items-center gap-1.5 bg-indigo-50 text-indigo-700 px-3 py-1 rounded-xl border border-indigo-200">
                        🔁 {item.recurrence}
                      </span>
                    )}
                    <span className="flex items-center gap-1.5 bg-slate-100 px-3 py-1 rounded-xl">
                      <Tag className="w-4 h-4 text-emerald-600" />
                      {item.category}
                    </span>
                  </div>

                  {item.correctionNote && (
                    <p className="text-xs font-semibold text-amber-700 bg-amber-50 px-3 py-1 rounded-xl inline-flex items-center gap-1 mt-1">
                      <AlertCircle className="w-3.5 h-3.5" /> {item.correctionNote}
                    </p>
                  )}
                </div>
              </div>

              {/* Right Side: Read Aloud, Edit & Delete */}
              <div className="flex items-center gap-2 self-end sm:self-center">
                <button
                  onClick={() => speakText(`Compromisso: ${item.title}, agendado para o dia ${item.date} às ${item.time}. Frequência: ${item.recurrence || 'Único'}. Prioridade ${item.priority}.`)}
                  className="p-3 bg-sky-50 hover:bg-sky-100 text-sky-700 rounded-2xl transition-all cursor-pointer shadow-sm"
                  title="Ouvir em voz alta"
                  aria-label="Ouvir compromisso em voz alta"
                >
                  <Volume2 className="w-6 h-6" />
                </button>

                <button
                  onClick={() => onEdit(item)}
                  className="p-3 bg-amber-50 hover:bg-amber-100 text-amber-700 rounded-2xl transition-all cursor-pointer shadow-sm"
                  title="Editar compromisso"
                  aria-label="Editar compromisso"
                >
                  <Pencil className="w-6 h-6" />
                </button>

                <button
                  onClick={() => onDelete(item.id)}
                  className="p-3 bg-red-50 hover:bg-red-100 text-red-600 rounded-2xl transition-all cursor-pointer shadow-sm"
                  title="Excluir compromisso"
                  aria-label="Excluir compromisso"
                >
                  <Trash2 className="w-6 h-6" />
                </button>
              </div>

            </div>
          ))}
        </div>
      )}

    </div>
  );
};

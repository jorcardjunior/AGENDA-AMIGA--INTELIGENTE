import React, { useState, useEffect } from 'react';
import { X, Save, Calendar, Clock, AlertCircle, Tag, Repeat } from 'lucide-react';
import { Commitment } from '../types';
import { formatNaturalDate } from '../utils/dateFormatter';

interface EditCommitmentModalProps {
  commitment: Commitment | null;
  isOpen: boolean;
  onClose: () => void;
  onSave: (updated: Commitment) => void;
  speakText: (text: string) => void;
}

export const EditCommitmentModal: React.FC<EditCommitmentModalProps> = ({
  commitment,
  isOpen,
  onClose,
  onSave,
  speakText,
}) => {
  const [title, setTitle] = useState('');
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [priority, setPriority] = useState<'Alta' | 'Média' | 'Baixa'>('Média');
  const [category, setCategory] = useState('Consulta');
  const [recurrence, setRecurrence] = useState('Único');

  useEffect(() => {
    if (commitment) {
      setTitle(commitment.title);
      setDate(commitment.date);
      setTime(commitment.time);
      setPriority(commitment.priority);
      setCategory(commitment.category || 'Consulta');
      setRecurrence(commitment.recurrence || 'Único');
    }
  }, [commitment]);

  if (!isOpen || !commitment) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !date || !time) return;

    const updated: Commitment = {
      ...commitment,
      title: title.trim(),
      date,
      time,
      priority,
      category,
      recurrence,
      correctionNote: 'Editado e atualizado.',
    };

    onSave(updated);
    const naturalDateStr = formatNaturalDate(date);
    speakText(`Compromisso ${title} atualizado para o dia ${naturalDateStr} às ${time}.`);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 bg-slate-900/80 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="bg-white rounded-[32px] max-w-lg w-full p-6 sm:p-8 shadow-2xl border border-slate-200 animate-in fade-in zoom-in duration-200">
        
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-emerald-100 text-emerald-700 rounded-2xl">
              <Calendar className="w-6 h-6" />
            </div>
            <div>
              <h3 className="text-xl font-black text-slate-900">Editar Compromisso</h3>
              <p className="text-xs text-slate-500">Altere os dados do lembrete ou remédio</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 text-slate-400 hover:text-slate-700 rounded-full hover:bg-slate-100 transition-all cursor-pointer"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-bold uppercase text-slate-600 mb-1">Título do Compromisso / Remédio</label>
            <input
              type="text"
              required
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-2xl text-slate-900 font-medium text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold uppercase text-slate-600 mb-1">Data</label>
              <input
                type="date"
                required
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-2xl text-slate-900 font-medium text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
            </div>
            <div>
              <label className="block text-xs font-bold uppercase text-slate-600 mb-1">Horário</label>
              <input
                type="time"
                required
                value={time}
                onChange={(e) => setTime(e.target.value)}
                className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-2xl text-slate-900 font-medium text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-bold uppercase text-slate-600 mb-1">Prioridade</label>
              <select
                value={priority}
                onChange={(e) => setPriority(e.target.value as any)}
                className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-2xl text-slate-900 font-medium text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
              >
                <option value="Alta">Alta</option>
                <option value="Média">Média</option>
                <option value="Baixa">Baixa</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-bold uppercase text-slate-600 mb-1">Categoria</label>
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-2xl text-slate-900 font-medium text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
              >
                <option value="Saúde/Remédio">Saúde/Remédio</option>
                <option value="Consulta">Consulta</option>
                <option value="Família">Família</option>
                <option value="Outros">Outros</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-bold uppercase text-slate-600 mb-1">Recorrência</label>
              <select
                value={recurrence}
                onChange={(e) => setRecurrence(e.target.value)}
                className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-2xl text-slate-900 font-medium text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
              >
                <option value="Único">Único</option>
                <option value="Todos os dias">Todos os dias</option>
                <option value="Semanal">Semanal</option>
              </select>
            </div>
          </div>

          <div className="flex items-center justify-end gap-3 pt-4 border-t">
            <button
              type="button"
              onClick={onClose}
              className="px-5 py-3 text-slate-600 hover:text-slate-900 font-bold text-sm cursor-pointer"
            >
              Cancelar
            </button>
            <button
              type="submit"
              className="px-6 py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-black text-sm rounded-2xl shadow-lg transition-all flex items-center gap-2 cursor-pointer"
            >
              <Save className="w-4 h-4" />
              <span>Salvar Alterações</span>
            </button>
          </div>
        </form>

      </div>
    </div>
  );
};

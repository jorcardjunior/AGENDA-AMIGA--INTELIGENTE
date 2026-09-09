import React from 'react';
import { Calendar as CalendarIcon } from 'lucide-react';

interface WeeklyCalendarProps {
  commitments: any[];
  selectedDate: string;
  onSelectDate: (dateStr: string) => void;
  speakText: (text: string) => void;
}

export const WeeklyCalendar: React.FC<WeeklyCalendarProps> = ({
  commitments,
  selectedDate,
  onSelectDate,
  speakText,
}) => {
  const fullDayNames: { [key: number]: string } = {
    0: 'Domingo',
    1: 'Segunda-feira',
    2: 'Terça-feira',
    3: 'Quarta-feira',
    4: 'Quinta-feira',
    5: 'Sexta-feira',
    6: 'Sábado',
  };

  const fullMonthNames: { [key: number]: string } = {
    0: 'janeiro',
    1: 'fevereiro',
    2: 'março',
    3: 'abril',
    4: 'maio',
    5: 'junho',
    6: 'julho',
    7: 'agosto',
    8: 'setembro',
    9: 'outubro',
    10: 'novembro',
    11: 'dezembro',
  };

  const shortDayNames = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  // Generate current week
  const today = new Date();
  const currentDayOfWeek = today.getDay();
  const startOfWeek = new Date(today);
  startOfWeek.setDate(today.getDate() - currentDayOfWeek);

  const weekDays = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(startOfWeek);
    d.setDate(startOfWeek.getDate() + i);
    const dateStr = d.toISOString().split('T')[0];
    return {
      dateObj: d,
      dateStr,
      dayName: shortDayNames[d.getDay()],
      fullName: fullDayNames[d.getDay()],
      dayNumber: d.getDate(),
      monthNumber: d.getMonth(),
      yearNumber: d.getFullYear(),
      monthShort: d.toLocaleString('pt-BR', { month: 'short' }),
      fullMonthName: fullMonthNames[d.getMonth()],
    };
  });

  return (
    <div className="bg-white rounded-3xl p-5 sm:p-6 shadow-sm border border-slate-200">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <span className="p-2 bg-emerald-100 text-emerald-700 rounded-2xl">
            <CalendarIcon className="w-5 h-5" />
          </span>
          <div>
            <h3 className="font-extrabold text-slate-900 text-base sm:text-lg">Agenda Semanal</h3>
            <p className="text-xs text-slate-500">Selecione o dia para ver os compromissos</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-7 gap-2">
        {weekDays.map((day) => {
          const isSelected = selectedDate === day.dateStr;
          
          // Count commitments for this specific day
          const dayCommitments = commitments.filter((c) => {
            const matchesDate = c.date === day.dateStr || c.recurrence === 'Todos os dias';
            return matchesDate && !c.completed;
          });
          const count = dayCommitments.length;

          const hasCompletedTasks = commitments.some((c) => c.date === day.dateStr && c.completed);

          return (
            <button
              key={day.dateStr}
              onClick={() => {
                onSelectDate(day.dateStr);
                
                // Natural spoken format: "segunda-feira, dia 7 de setembro de 2026"
                const naturalDateSpeech = `${day.fullName}, dia ${day.dayNumber} de ${day.fullMonthName} de ${day.yearNumber}`;
                
                const countMsg = count === 0
                  ? `Nenhum compromisso pendente para ${naturalDateSpeech}.`
                  : count === 1
                  ? `1 compromisso pendente para ${naturalDateSpeech}.`
                  : `${count} compromissos pendentes para ${naturalDateSpeech}.`;

                speakText(countMsg);
              }}
              className={`flex flex-col items-center justify-center p-2.5 sm:p-3 rounded-2xl transition-all cursor-pointer border ${
                isSelected
                  ? 'bg-emerald-600 text-white border-emerald-600 shadow-md shadow-emerald-600/30 scale-105'
                  : 'bg-slate-50 hover:bg-slate-100 text-slate-800 border-slate-200'
              }`}
            >
              <span className={`text-[10px] sm:text-xs font-bold uppercase tracking-wider ${isSelected ? 'text-emerald-100' : 'text-slate-500'}`}>
                {day.dayName}
              </span>
              <span className="text-base sm:text-xl font-black my-0.5">
                {day.dayNumber}
              </span>
              <span className={`text-[10px] capitalize ${isSelected ? 'text-emerald-100' : 'text-slate-400'}`}>
                {day.monthShort}
              </span>

              {/* Indicator dots */}
              <div className="flex items-center gap-1 mt-1.5 h-2">
                {count > 0 && (
                  <span className={`w-1.5 h-1.5 rounded-full ${isSelected ? 'bg-white animate-pulse' : 'bg-emerald-500'}`} title={`${count} pendências`} />
                )}
                {hasCompletedTasks && count === 0 && (
                  <span className={`w-1.5 h-1.5 rounded-full ${isSelected ? 'bg-emerald-200' : 'bg-blue-400'}`} title="Concluídos" />
                )}
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
};

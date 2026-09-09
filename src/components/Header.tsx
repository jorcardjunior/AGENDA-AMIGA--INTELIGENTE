import React from 'react';
import { Mic, Calendar, PhoneCall, HelpCircle, Volume2, Square } from 'lucide-react';

interface HeaderProps {
  onOpenCalendarSync: () => void;
  onOpenTutorial: () => void;
  onEmergencyCall: () => void;
  onReadDailyBriefing: () => void;
  onStopSpeech: () => void;
  isSpeaking: boolean;
}

export const Header: React.FC<HeaderProps> = ({
  onOpenCalendarSync,
  onOpenTutorial,
  onEmergencyCall,
  onReadDailyBriefing,
  onStopSpeech,
  isSpeaking,
}) => {
  return (
    <header className="bg-white border-b-2 border-emerald-100 shadow-sm sticky top-0 z-30">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-20 flex items-center justify-between">
        
        {/* Logo & Title */}
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 bg-emerald-600 text-white rounded-2xl flex items-center justify-center shadow-md">
            <Mic className="w-7 h-7 animate-pulse" />
          </div>
          <div>
            <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
              Agenda Amiga <span className="text-xs bg-emerald-100 text-emerald-800 font-bold px-2 py-0.5 rounded-full">Voz</span>
            </h1>
            <p className="text-xs sm:text-sm font-medium text-slate-500">
              Sua agenda inteligente que fala e escuta você
            </p>
          </div>
        </div>

        {/* Action Buttons (Large, high contrast for seniors) */}
        <div className="flex items-center gap-2 sm:gap-3">
          <button
            onClick={onReadDailyBriefing}
            className="flex items-center gap-2 px-3.5 py-2.5 bg-sky-50 hover:bg-sky-100 text-sky-700 font-bold rounded-2xl border border-sky-200 transition-all text-sm sm:text-base cursor-pointer shadow-sm"
            title="Ouvir Resumo do Dia"
          >
            <Volume2 className="w-5 h-5 text-sky-600" />
            <span className="hidden md:inline">Ouvir Resumo</span>
          </button>

          {isSpeaking && (
            <button
              onClick={onStopSpeech}
              className="flex items-center gap-2 px-3.5 py-2.5 bg-red-100 hover:bg-red-200 text-red-700 font-bold rounded-2xl border border-red-300 transition-all text-sm sm:text-base cursor-pointer animate-pulse shadow-sm"
              title="Parar áudio"
            >
              <Square className="w-5 h-5 fill-current" />
              <span className="hidden sm:inline">Parar Áudio</span>
            </button>
          )}

          <button
            onClick={onOpenCalendarSync}
            className="flex items-center gap-2 px-3.5 py-2.5 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 font-bold rounded-2xl border border-indigo-200 transition-all text-sm sm:text-base cursor-pointer shadow-sm"
            title="Sincronizar Calendários"
          >
            <Calendar className="w-5 h-5 text-indigo-600" />
            <span className="hidden md:inline">Sincronizar</span>
          </button>

          <button
            onClick={onOpenTutorial}
            className="p-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-2xl transition-all cursor-pointer shadow-sm"
            title="Ajuda e Como Falar"
          >
            <HelpCircle className="w-6 h-6" />
          </button>

          <button
            onClick={onEmergencyCall}
            className="flex items-center gap-2 px-4 py-2.5 bg-red-600 hover:bg-red-700 text-white font-black rounded-2xl shadow-md transition-all text-sm sm:text-base cursor-pointer animate-bounce hover:animate-none"
            title="Ligar para Familiar / Cuidador"
          >
            <PhoneCall className="w-5 h-5" />
            <span>Ajuda / Família</span>
          </button>
        </div>

      </div>
    </header>
  );
};


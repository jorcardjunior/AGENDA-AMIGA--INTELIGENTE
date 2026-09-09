import React from 'react';
import { X, Mic, HelpCircle, Volume2, Sparkles } from 'lucide-react';

interface VoiceTutorialModalProps {
  isOpen: boolean;
  onClose: () => void;
  speakText: (text: string) => void;
}

export const VoiceTutorialModal: React.FC<VoiceTutorialModalProps> = ({ isOpen, onClose, speakText }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
      <div className="bg-white rounded-3xl max-w-2xl w-full p-6 sm:p-8 shadow-2xl border-4 border-sky-500 animate-in fade-in zoom-in-95 duration-200">
        
        <div className="flex items-center justify-between pb-4 border-b">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-sky-100 text-sky-700 rounded-2xl">
              <HelpCircle className="w-7 h-7" />
            </div>
            <div>
              <h3 className="text-xl font-black text-slate-900">Como Usar a Agenda por Voz</h3>
              <p className="text-xs font-medium text-slate-500">Guia rápido e simples</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2.5 bg-slate-100 hover:bg-red-100 text-slate-700 hover:text-red-700 rounded-full transition-colors cursor-pointer"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="py-6 space-y-6 text-slate-700">
          <div className="bg-sky-50 p-5 rounded-2xl border border-sky-200 flex items-start gap-4">
            <div className="p-3 bg-sky-600 text-white rounded-2xl shrink-0">
              <Mic className="w-6 h-6" />
            </div>
            <div>
              <h4 className="font-bold text-sky-900 text-lg">1. Toque no Grande Microfone</h4>
              <p className="text-sm text-slate-600 mt-1">
                Basta tocar no botão redondo verde no centro da tela e falar o que você precisa lembrar. 
                Não se preocupe se errar o horário, nossa inteligência artificial ajusta para você!
              </p>
            </div>
          </div>

          <div className="bg-emerald-50 p-5 rounded-2xl border border-emerald-200 flex items-start gap-4">
            <div className="p-3 bg-emerald-600 text-white rounded-2xl shrink-0">
              <Volume2 className="w-6 h-6" />
            </div>
            <div>
              <h4 className="font-bold text-emerald-900 text-lg">2. Avisos e Lembretes em Voz Alta</h4>
              <p className="text-sm text-slate-600 mt-1">
                O aplicativo fala com você em voz alta quando chegar a hora do compromisso ou do remédio. 
                Você também pode tocar no alto-falante ao lado de qualquer tarefa para ouvir novamente.
              </p>
            </div>
          </div>

          <div className="bg-amber-50 p-5 rounded-2xl border border-amber-200 flex items-start gap-4">
            <div className="p-3 bg-amber-600 text-white rounded-2xl shrink-0">
              <Sparkles className="w-6 h-6" />
            </div>
            <div>
              <h4 className="font-bold text-amber-900 text-lg">3. Jardim da Vida (Gamificação)</h4>
              <p className="text-sm text-slate-600 mt-1">
                Cada tarefa cumprida rega seu jardim virtual e faz lindas flores desabrocharem, trazendo alegria 
                e parabéns carinhosos todos os dias!
              </p>
            </div>
          </div>
        </div>

        <div className="pt-4 border-t flex items-center justify-between">
          <button
            onClick={() => speakText('Bem-vindo à Agenda Amiga. Basta tocar no microfone e falar o que deseja lembrar.')}
            className="px-4 py-2.5 bg-sky-100 hover:bg-sky-200 text-sky-800 font-bold rounded-xl flex items-center gap-2 cursor-pointer text-sm"
          >
            <Volume2 className="w-4 h-4" /> Ouvir Explicação em Voz
          </button>

          <button
            onClick={onClose}
            className="px-6 py-3 bg-sky-600 hover:bg-sky-700 text-white font-bold rounded-2xl shadow transition-all cursor-pointer"
          >
            Entendido, Vamos Começar!
          </button>
        </div>

      </div>
    </div>
  );
};

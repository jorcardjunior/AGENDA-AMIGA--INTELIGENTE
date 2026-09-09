import React, { useEffect, useRef } from 'react';
import { BellRing, CheckCircle2, Clock } from 'lucide-react';

interface AlarmRingingModalProps {
  isOpen: boolean;
  onClose: () => void;
  alarmTitle: string;
  alarmTime: string;
  speakText: (text: string, onStart?: () => void, onEnd?: () => void) => void;
  stopSpeech: () => void;
  onConfirmDone: () => void;
}

export const AlarmRingingModal: React.FC<AlarmRingingModalProps> = ({
  isOpen,
  onClose,
  alarmTitle,
  alarmTime,
  speakText,
  stopSpeech,
  onConfirmDone,
}) => {
  const recognitionRef = useRef<any>(null);

  useEffect(() => {
    if (isOpen) {
      if ('vibrate' in navigator) {
        try { navigator.vibrate([500, 200, 500, 200, 500, 200, 500]); } catch (e) {}
      }
      
      const announcement = `Atenção! Hora do compromisso ou remédio: ${alarmTitle}. Diga desligar, ok ou já ouvi para silenciar.`;
      
      // Professional Anti-Echo Architecture:
      // 1. Speak announcement
      // 2. ONLY when speech finishes completely (onEnd), start listening to the microphone.
      // This prevents the mic from ever capturing the AI's own voice and self-triggering.
      speakText(
        announcement,
        () => {},
        () => {
          startAlarmListening();
        }
      );
    }

    return () => {
      stopAlarmListening();
    };
  }, [isOpen]);

  const startAlarmListening = () => {
    const SpeechRecognitionAPI = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (SpeechRecognitionAPI) {
      try {
        const recognition = new SpeechRecognitionAPI();
        recognitionRef.current = recognition;
        recognition.lang = 'pt-BR';
        recognition.continuous = true;
        recognition.interimResults = true;

        recognition.onresult = (event: any) => {
          for (let i = event.resultIndex; i < event.results.length; ++i) {
            const spoken = event.results[i][0].transcript.toLowerCase();
            if (['desligar', 'chega', 'basta', 'já ouvi', 'ok', 'obrigado', 'valeu', 'parar', 'sim', 'tomei'].some(w => spoken.includes(w))) {
              stopAlarmListening();
              stopSpeech();
              onConfirmDone();
              speakText('Alarme desligado com sucesso.');
              onClose();
            }
          }
        };

        recognition.start();
      } catch (e) {
        // fallback
      }
    }
  };

  const stopAlarmListening = () => {
    if (recognitionRef.current) {
      try { recognitionRef.current.stop(); } catch (e) {}
      recognitionRef.current = null;
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-red-950/85 backdrop-blur-md flex items-center justify-center p-4 animate-in fade-in zoom-in duration-200">
      <div className="bg-white rounded-[40px] max-w-md w-full p-8 shadow-2xl border-4 border-red-500 text-center space-y-6">
        
        <div className="w-28 h-28 bg-red-100 text-red-600 rounded-full flex items-center justify-center mx-auto shadow-inner animate-bounce">
          <BellRing className="w-14 h-14" />
        </div>

        <div>
          <span className="inline-block px-4 py-1 bg-red-100 text-red-700 font-black text-xs rounded-full uppercase tracking-wider mb-2">
            ⏰ ALARME DISPARADO AGORA
          </span>
          <h3 className="text-3xl font-black text-slate-900 leading-tight">
            {alarmTitle}
          </h3>
          <p className="text-emerald-600 font-bold text-lg mt-2 flex items-center justify-center gap-1.5">
            <Clock className="w-5 h-5" /> Horário: {alarmTime}
          </p>
        </div>

        <div className="bg-amber-50 border border-amber-200 p-4 rounded-2xl text-amber-900 text-xs font-semibold">
          🎙️ Você pode dizer <strong className="text-red-700">"Desligar"</strong>, <strong className="text-red-700">"Já ouvi"</strong> ou <strong className="text-red-700">"Ok"</strong>, ou tocar no botão abaixo.
        </div>

        <div className="space-y-3 pt-2">
          <button
            onClick={() => {
              stopAlarmListening();
              stopSpeech();
              onConfirmDone();
              speakText('Remédio tomado e registrado.');
              onClose();
            }}
            className="w-full py-4 bg-emerald-600 hover:bg-emerald-700 text-white font-black text-lg rounded-2xl shadow-lg transition-all flex items-center justify-center gap-2 cursor-pointer"
          >
            <CheckCircle2 className="w-6 h-6" />
            <span>Já Tomei / Realizei!</span>
          </button>

          <button
            onClick={() => {
              stopAlarmListening();
              stopSpeech();
              speakText('Alarme adiado por 10 minutos.');
              onClose();
            }}
            className="w-full py-3 bg-amber-100 hover:bg-amber-200 text-amber-800 font-bold rounded-2xl transition-all cursor-pointer"
          >
            Adiar por 10 Minutos
          </button>
        </div>

      </div>
    </div>
  );
};

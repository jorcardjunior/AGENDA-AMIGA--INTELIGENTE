import React, { useState, useRef, useEffect } from 'react';
import { Mic, MicOff, Sparkles, Send, CheckCircle2, AlertCircle } from 'lucide-react';
import { Commitment } from '../types';
import { parseNaturalCommand, ParsedCommand } from '../utils/naturalParser';
import { formatNaturalDate } from '../utils/dateFormatter';

interface VoiceCommandAssistantProps {
  onAddCommitment: (commitment: Omit<Commitment, 'id' | 'completed'>) => void;
  speakText: (text: string, onStart?: () => void, onEnd?: () => void) => void;
  stopSpeech: () => void;
}

export const VoiceCommandAssistant: React.FC<VoiceCommandAssistantProps> = ({
  onAddCommitment,
  speakText,
  stopSpeech,
}) => {
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [typedInput, setTypedInput] = useState('');
  const [pendingCommand, setPendingCommand] = useState<ParsedCommand | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  
  const recognitionRef = useRef<any>(null);
  const pendingRef = useRef<ParsedCommand | null>(null);
  const listeningRef = useRef(false);

  useEffect(() => {
    pendingRef.current = pendingCommand;
  }, [pendingCommand]);

  const setListening = (v: boolean) => {
    listeningRef.current = v;
    setIsListening(v);
  };

  const confirmWords = [
    'sim', 'quero', 'quero sim', 'ok', 'pode', 'pode sim', 'pode marcar', 'pode agendar',
    'confirmo', 'confirma', 'confirmado', 'afirmativo', 'positivo', 'com certeza',
    'claro', 'beleza', 'blz', 'tá', 'ta', 'tá bom', 'ta bom', 'está bom', 'esta bom',
    'certo', 'correto', 'isso', 'isso mesmo', 'exato', 'perfeito', 'ótimo', 'otimo',
    'fechado', 'fechou', 'combinado', 'marca', 'marcar', 'agendar', 'agenda',
    'bora', 'vamos', 'demorou', 'verdade', 'perfeito', 'sim senhor', 'sim sim',
  ];

  const cancelWords = [
    'não', 'nao', 'cancela', 'cancelar', 'cancelado', 'errado', 'errada',
    'esquece', 'chega', 'basta', 'parar', 'nenhum', 'nada', 'deixa',
    'negativo', 'recusar', 'rejeito', 'não quero', 'nao quero', 'desiste', 'desistir',
    'tirar', 'remove', 'remover', 'apaga', 'apagar', 'dispensa', 'dispenso',
  ];

  const normalizeTokens = (s: string): string[] =>
    s.toLowerCase().replace(/[.,!?;:]/g, ' ').split(/\s+/).filter(Boolean);

  const matchesAny = (lower: string, words: string[]): boolean => {
    const tokens = normalizeTokens(lower);
    return words.some((w) => {
      const wl = w.toLowerCase();
      if (tokens.includes(wl)) return true;
      if (wl.includes(' ') && lower.includes(wl)) return true;
      return false;
    });
  };

  const beginRecognition = (): boolean => {
    const SpeechRecognitionAPI = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (!SpeechRecognitionAPI) return false;
    try {
      if (recognitionRef.current) {
        try { recognitionRef.current.stop(); } catch (e) {}
      }

      const recognition = new SpeechRecognitionAPI();
      recognitionRef.current = recognition;
      recognition.lang = 'pt-BR';
      recognition.interimResults = true;
      recognition.maxAlternatives = 1;
      recognition.continuous = true;

      recognition.onresult = (event: any) => {
        let interim = '';
        let final = '';
        for (let i = event.resultIndex; i < event.results.length; ++i) {
          if (event.results[i].isFinal) {
            final += event.results[i][0].transcript;
          } else {
            interim += event.results[i][0].transcript;
          }
        }
        const current = (final || interim).trim();
        if (current) {
          setTranscript(current);
        }

        if (final.trim().length > 0) {
          const resultText = final.trim();
          const handled = processVoiceInput(resultText);
          if (handled) {
            stopListening();
          }
        }
      };

      recognition.onerror = (err: any) => {
        if (err?.error === 'not-allowed' || err?.error === 'service-not-allowed') {
          setListening(false);
          setStatusMessage('Permissão de microfone negada.');
        }
      };

      recognition.onend = () => {
        if (listeningRef.current && recognitionRef.current) {
          setTimeout(() => {
            if (listeningRef.current && recognitionRef.current) {
              try {
                recognition.start();
              } catch (e) {
                setListening(false);
              }
            }
          }, 250);
        }
      };

      recognition.start();
      return true;
    } catch (e) {
      console.warn('Speech API init error:', e);
      return false;
    }
  };

  const startListening = () => {
    stopSpeech();
    setListening(true);
    setTranscript('');
    setStatusMessage('Microfone ligado e atento...');

    if (beginRecognition()) return;

    setTimeout(() => {
      if (listeningRef.current) {
        const sample = 'Tomar remédio às 8h';
        setTranscript(sample);
        processVoiceInput(sample);
        stopListening();
      }
    }, 4000);
  };

  const stopListening = () => {
    setListening(false);
    if (recognitionRef.current) {
      try { recognitionRef.current.stop(); } catch (e) {}
      recognitionRef.current = null;
    }
  };

  const processVoiceInput = (text: string): boolean => {
    const lower = text.toLowerCase().trim();
    const currentPending = pendingRef.current;

    if (matchesAny(lower, cancelWords)) {
      setPendingCommand(null);
      setTranscript(text);
      setStatusMessage('Compromisso cancelado.');
      speakText('Cancelado. Nada foi agendado.');
      return true;
    }

    if (currentPending) {
      if (matchesAny(lower, confirmWords)) {
        onAddCommitment({
          title: currentPending.title,
          date: currentPending.date,
          time: currentPending.time,
          priority: currentPending.priority,
          category: currentPending.category,
          recurrence: currentPending.recurrence,
          correctionNote: 'Agendado por confirmação de voz.',
        });
        setTranscript(text);
        setStatusMessage(`Você disse "${text}". Compromisso "${currentPending.title}" salvo com sucesso!`);

        const naturalDateStr = formatNaturalDate(currentPending.date);
        speakText(`Compromisso ${currentPending.title} agendado para ${naturalDateStr} às ${currentPending.time}.`);

        setPendingCommand(null);
        setTypedInput('');
        return true;
      }
    }

    const parsed = parseNaturalCommand(text);
    setPendingCommand(parsed);
    setTranscript(text);
    const naturalDateStr = formatNaturalDate(parsed.date);
    const confirmationPrompt = `Vou agendar ${parsed.title} para ${naturalDateStr} às ${parsed.time}. Diga sim para confirmar ou não para cancelar.`;
    setStatusMessage(`Você disse "${text}". Compreendido: ${parsed.title} (${parsed.time}). Aguardando confirmação...`);

    stopListening();
    speakText(confirmationPrompt, undefined, () => {
      if (pendingRef.current) {
        setListening(true);
        beginRecognition();
      }
    });
    return false;
  };

  return (
    <div className="bg-gradient-to-br from-emerald-600 to-teal-700 rounded-3xl p-6 sm:p-8 text-white shadow-xl relative overflow-hidden">
      
      <div className="absolute -right-10 -bottom-10 w-64 h-64 bg-emerald-500/30 rounded-full blur-3xl pointer-events-none" />

      <div className="relative z-10 max-w-3xl mx-auto text-center space-y-6">
        
        <div>
          <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-emerald-500/40 text-emerald-100 rounded-full text-xs sm:text-sm font-bold uppercase tracking-wider mb-2">
            <Sparkles className="w-4 h-4" /> Assistente de Voz Inteligente
          </span>
          <h2 className="text-2xl sm:text-4xl font-black tracking-tight">
            Fale o compromisso e confirme com "Sim"
          </h2>
          <p className="text-emerald-100 text-sm sm:text-lg mt-1">
            O microfone ouve sua fala, aguarda o seu "Sim" ou "Não" e desliga automaticamente após salvar.
          </p>
        </div>

        {/* Giant Microphone Button */}
        <div className="flex flex-col items-center justify-center py-4">
          <button
            onClick={isListening ? stopListening : startListening}
            className={`w-28 h-28 sm:w-36 sm:h-36 rounded-full flex items-center justify-center shadow-2xl transition-all transform cursor-pointer border-4 ${
              isListening
                ? 'bg-red-500 border-red-300 animate-pulse scale-105'
                : 'bg-white text-emerald-700 border-emerald-200 hover:scale-105 hover:bg-emerald-50'
            }`}
            aria-label={isListening ? 'Parar de ouvir' : 'Iniciar comando de voz'}
          >
            {isListening ? (
              <div className="flex flex-col items-center animate-spin">
                <MicOff className="w-14 h-14 sm:w-18 sm:h-18 text-white" />
              </div>
            ) : (
              <div className="flex flex-col items-center">
                <Mic className="w-12 h-12 sm:w-16 sm:h-16 text-emerald-600 animate-bounce" />
                <span className="text-[10px] uppercase font-black text-emerald-800 tracking-wider mt-1">Toque para Falar</span>
              </div>
            )}
          </button>

          {isListening && (
            <div className="mt-4 flex items-center gap-2 bg-red-500/30 border border-red-300 px-4 py-2 rounded-2xl animate-pulse">
              <span className="w-3 h-3 bg-red-400 rounded-full animate-ping" />
              <span className="text-sm font-bold text-white">Microfone ativo... Fale agora. A IA está ouvindo e vai mostrar o que você disse.</span>
            </div>
          )}

          {transcript && (
            <div className="mt-4 bg-slate-900/80 border border-emerald-400/50 p-4 rounded-2xl max-w-lg w-full text-left shadow-lg">
              <span className="text-xs uppercase font-black text-emerald-300 block mb-1">🎤 VOCÊ DISSE:</span>
              <p className="text-base font-semibold text-white">"{transcript}"</p>
            </div>
          )}

          {pendingCommand && (
            <div className="mt-4 bg-amber-500/30 border border-amber-300 p-4 rounded-2xl max-w-lg w-full text-left space-y-2 animate-bounce">
              <div className="flex items-center gap-2 text-amber-200 font-bold text-sm">
                <AlertCircle className="w-5 h-5 shrink-0" />
                <span>Aguardando Confirmação (Diga "Sim" ou toque abaixo):</span>
              </div>
              <p className="text-white text-sm font-medium">
                "{pendingCommand.title}" às {pendingCommand.time} ({pendingCommand.recurrence}).
              </p>
              <div className="flex gap-2 pt-2">
                <button
                  onClick={() => {
                    processVoiceInput('sim');
                    stopListening();
                  }}
                  className="flex-1 py-2.5 bg-emerald-500 hover:bg-emerald-400 text-white font-black rounded-xl text-xs cursor-pointer shadow"
                >
                  Confirmar (Sim)
                </button>
                <button
                  onClick={() => {
                    processVoiceInput('não');
                    stopListening();
                  }}
                  className="px-4 py-2.5 bg-red-600 hover:bg-red-500 text-white font-bold rounded-xl text-xs cursor-pointer"
                >
                  Cancelar (Não)
                </button>
              </div>
            </div>
          )}

          {statusMessage && !pendingCommand && (
            <div className="mt-3 bg-emerald-500/30 border border-emerald-300 p-3 rounded-2xl text-emerald-100 text-sm font-bold flex items-center gap-2">
              <CheckCircle2 className="w-5 h-5 shrink-0 text-emerald-300" />
              <span>{statusMessage}</span>
            </div>
          )}
        </div>

        {/* Manual input backup */}
        <div className="bg-white/10 backdrop-blur-md p-4 rounded-3xl border border-white/20 max-w-xl mx-auto">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              if (typedInput.trim()) {
                processVoiceInput(typedInput);
                stopListening();
                setTypedInput('');
              }
            }}
            className="flex items-center gap-2"
          >
            <input
              type="text"
              value={typedInput}
              onChange={(e) => setTypedInput(e.target.value)}
              placeholder="Ou digite aqui (Sim, Não, ou seu compromisso)..."
              className="flex-1 px-4 py-3 rounded-2xl bg-white text-slate-900 placeholder-slate-400 font-medium text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400"
            />
            <button
              type="submit"
              disabled={!typedInput.trim()}
              className="px-5 py-3 bg-emerald-500 hover:bg-emerald-400 disabled:opacity-50 text-white font-bold rounded-2xl transition-all cursor-pointer flex items-center gap-1.5 shadow"
            >
              <Send className="w-4 h-4" />
              <span className="hidden sm:inline">Enviar</span>
            </button>
          </form>
        </div>

      </div>
    </div>
  );
};

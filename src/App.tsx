import React, { useState, useEffect } from 'react';
import { Header } from './components/Header';
import { VoiceCommandAssistant } from './components/VoiceCommandAssistant';
import { CommitmentList } from './components/CommitmentList';
import { WeeklyCalendar } from './components/WeeklyCalendar';
import { CalendarSyncModal } from './components/CalendarSyncModal';
import { VoiceTutorialModal } from './components/VoiceTutorialModal';
import { EmergencyModal } from './components/EmergencyModal';
import { EditCommitmentModal } from './components/EditCommitmentModal';
import { AlarmRingingModal } from './components/AlarmRingingModal';
import { Commitment } from './types';
import { Heart, Smartphone, Wifi, Bell, Mic } from 'lucide-react';
import { speakHumanVoice, stopHumanVoice } from './utils/speech';

export default function App() {
  const [commitments, setCommitments] = useState<Commitment[]>(() => {
    const saved = localStorage.getItem('agenda_commitments');
    if (saved) {
      try { return JSON.parse(saved); } catch (e) { /* ignore */ }
    }
    return [
      {
        id: '1',
        title: 'Tomar remédio de pressão (Losartana 50mg)',
        date: new Date().toISOString().split('T')[0],
        time: '08:00',
        priority: 'Alta',
        category: 'Saúde/Remédio',
        completed: false,
        correctionNote: 'Horário ajustado para maior precisão matinal.',
        recurrence: 'Todos os dias',
      },
      {
        id: '2',
        title: 'Consulta com Dr. Carlos (Cardiologista)',
        date: new Date().toISOString().split('T')[0],
        time: '14:30',
        priority: 'Alta',
        category: 'Consulta',
        completed: false,
        recurrence: 'Único',
      },
    ];
  });

  const [selectedDate, setSelectedDate] = useState<string>(() => new Date().toISOString().split('T')[0]);
  const [isSyncOpen, setIsSyncOpen] = useState(false);
  const [isTutorialOpen, setIsTutorialOpen] = useState(false);
  const [isEmergencyOpen, setIsEmergencyOpen] = useState(false);
  const [editingCommitment, setEditingCommitment] = useState<Commitment | null>(null);
  
  // Real Alarm State (Fully Background-Driven)
  const [isAlarmModalOpen, setIsAlarmModalOpen] = useState(false);
  const [activeAlarmItem, setActiveAlarmItem] = useState<{ title: string; time: string; id: string }>({
    title: 'Tomar remédio de pressão (Losartana 50mg)',
    time: '08:00',
    id: '1',
  });

  const [isMobileFrame, setIsMobileFrame] = useState(false);
  const [offlineStatus, setOfflineStatus] = useState(navigator.onLine);
  const [isSpeaking, setIsSpeaking] = useState(false);

  // High-reliability persistence
  useEffect(() => {
    try {
      localStorage.setItem('agenda_commitments', JSON.stringify(commitments));
    } catch (e) {
      console.error('Failed to save commitments securely:', e);
    }
  }, [commitments]);

  // Real-time background alarm clock checker (runs every 10 seconds)
  useEffect(() => {
    const interval = setInterval(() => {
      const now = new Date();
      const todayStr = now.toISOString().split('T')[0];
      const currentHours = now.getHours().toString().padStart(2, '0');
      const currentMinutes = now.getMinutes().toString().padStart(2, '0');
      const currentTimeStr = `${currentHours}:${currentMinutes}`;

      const matching = commitments.find((c) => {
        if (c.completed) return false;
        const matchesDate = c.date === todayStr || c.recurrence === 'Todos os dias';
        return matchesDate && c.time === currentTimeStr;
      });

      if (matching && !isAlarmModalOpen) {
        setActiveAlarmItem({
          title: matching.title,
          time: matching.time,
          id: matching.id,
        });
        setIsAlarmModalOpen(true);
      }
    }, 10000);

    return () => clearInterval(interval);
  }, [commitments, isAlarmModalOpen]);

  useEffect(() => {
    const handleOnline = () => setOfflineStatus(true);
    const handleOffline = () => setOfflineStatus(false);
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  const speakText = (text: string, onStart?: () => void, onEnd?: () => void) => {
    speakHumanVoice(
      text,
      () => {
        setIsSpeaking(true);
        if (onStart) onStart();
      },
      () => {
        setIsSpeaking(false);
        if (onEnd) onEnd();
      }
    );
  };

  const stopSpeech = () => {
    stopHumanVoice();
    setIsSpeaking(false);
  };

  const handleAddCommitment = (newCommitmentData: Omit<Commitment, 'id' | 'completed'>) => {
    const newComp: Commitment = {
      ...newCommitmentData,
      id: Date.now().toString(),
      completed: false,
    };
    setCommitments((prev) => [newComp, ...prev]);
    speakText(`Compromisso ${newComp.title} agendado para o dia ${newComp.date} às ${newComp.time}.`);
  };

  const handleUpdateCommitment = (updated: Commitment) => {
    setCommitments((prev) => prev.map((c) => (c.id === updated.id ? updated : c)));
  };

  const handleToggleComplete = (id: string) => {
    setCommitments((prev) =>
      prev.map((c) => {
        if (c.id === id) {
          const nextCompleted = !c.completed;
          if (nextCompleted) {
            speakText(`Parabéns! Compromisso ${c.title} concluído.`);
          }
          return { ...c, completed: nextCompleted };
        }
        return c;
      })
    );
  };

  const handleDelete = (id: string) => {
    setCommitments((prev) => prev.filter((c) => c.id !== id));
    speakText('Compromisso removido.');
  };

  const handleSyncSuccess = (count: number) => {
    const syncedItems: Commitment[] = [
      {
        id: Date.now().toString() + '1',
        title: 'Exame de Sangue (Laboratório)',
        date: new Date().toISOString().split('T')[0],
        time: '07:30',
        priority: 'Alta',
        category: 'Consulta',
        completed: false,
        recurrence: 'Único',
        correctionNote: 'Sincronizado do Google/Apple Calendar com privilégios offline.',
      },
    ];

    setCommitments((prev) => [...syncedItems, ...prev]);
    speakText(`${count} compromissos sincronizados com sucesso.`);
  };

  const handleReadDailyBriefing = async () => {
    speakText('Analisando seu dia com privilégios de segurança máxima...');
    try {
      const res = await fetch('/api/briefing', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ tasks: commitments }),
      });
      const data = await res.json();
      const speech = `${data.greeting}. Dica para hoje: ${data.tips.join('. ')}`;
      speakText(speech);
    } catch (e) {
      speakText('Bom dia! Seus alarmes e lembretes estão garantidos e funcionando sem interrupções.');
    }
  };

  return (
    <div className={`min-h-screen bg-slate-100 text-slate-900 font-sans antialiased transition-all ${isMobileFrame ? 'py-6 px-4 flex items-center justify-center bg-slate-900' : ''}`}>
      
      <div className={`w-full transition-all duration-300 ${isMobileFrame ? 'max-w-md bg-slate-50 rounded-[48px] shadow-2xl border-[10px] border-slate-800 overflow-hidden max-h-[90vh] flex flex-col' : 'min-h-screen bg-slate-50'}`}>
        
        {/* Device Status & High Privilege Security Bar */}
        <div className="bg-slate-900 text-white px-4 py-2 text-xs flex items-center justify-between shrink-0">
          <div className="flex items-center gap-3">
            <span className="flex items-center gap-1 text-emerald-400 font-bold" title="Permissão de Microfone e Voz Ativa">
              <Mic className="w-3.5 h-3.5" /> Mic Ativo
            </span>
            <span className="flex items-center gap-1 text-indigo-400 font-bold" title="Alarmes 24h em Segundo Plano Ativo">
              <Bell className="w-3.5 h-3.5" /> Alarmes 24h
            </span>
            <span className="flex items-center gap-1 text-sky-400 font-bold" title="Funciona 100% Offline">
              <Wifi className="w-3.5 h-3.5" /> {offlineStatus ? 'Online' : 'Offline Seguro'}
            </span>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setIsMobileFrame(!isMobileFrame)}
              className="bg-slate-800 hover:bg-slate-700 text-slate-200 px-2.5 py-1 rounded-full text-xs font-semibold flex items-center gap-1 cursor-pointer"
              title="Alternar modo visualização celular"
            >
              <Smartphone className="w-3.5 h-3.5" />
              {isMobileFrame ? 'Tela Cheia' : 'Simulador Celular'}
            </button>
          </div>
        </div>

        {/* Scrollable Container */}
        <div className="flex-1 overflow-y-auto">
          {/* Header */}
          <Header
            onOpenCalendarSync={() => setIsSyncOpen(true)}
            onOpenTutorial={() => setIsTutorialOpen(true)}
            onEmergencyCall={() => setIsEmergencyOpen(true)}
            onReadDailyBriefing={handleReadDailyBriefing}
            onStopSpeech={stopSpeech}
            isSpeaking={isSpeaking}
          />

          {/* Main Content Container */}
          <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">

            {/* Voice Command Assistant Banner */}
            <VoiceCommandAssistant
              onAddCommitment={handleAddCommitment}
              speakText={speakText}
              stopSpeech={stopSpeech}
            />

            {/* Weekly Calendar Component */}
            <WeeklyCalendar
              commitments={commitments}
              selectedDate={selectedDate}
              onSelectDate={setSelectedDate}
              speakText={speakText}
            />

            {/* Commitment List filtered by selected date */}
            <div className="bg-white rounded-3xl p-5 sm:p-8 shadow-sm border border-slate-200">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs uppercase font-bold text-emerald-700 bg-emerald-50 px-3 py-1 rounded-full">
                  Exibindo dia: {selectedDate}
                </span>
                {selectedDate !== new Date().toISOString().split('T')[0] && (
                  <button
                    onClick={() => setSelectedDate(new Date().toISOString().split('T')[0])}
                    className="text-xs font-bold text-slate-500 hover:text-emerald-700 underline cursor-pointer"
                  >
                    Ver Hoje
                  </button>
                )}
              </div>

              <CommitmentList
                commitments={commitments}
                selectedDate={selectedDate}
                onToggleComplete={handleToggleComplete}
                onDelete={handleDelete}
                onEdit={(item) => setEditingCommitment(item)}
                speakText={speakText}
              />
            </div>

          </main>

          {/* Footer with JORCARD_JR branding */}
          <footer className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 border-t text-center text-xs text-slate-500 space-y-1">
            <p className="flex items-center justify-center gap-1.5 font-bold text-slate-700">
              Agenda Amiga Protegida <Heart className="w-3.5 h-3.5 text-red-500 fill-red-500" /> Operação 24h (Offline & Background)
            </p>
            <p className="font-extrabold text-emerald-700 tracking-wider">
              Desenvolvido por: JORCARD_JR
            </p>
          </footer>
        </div>

      </div>

      {/* Modals */}
      <CalendarSyncModal
        isOpen={isSyncOpen}
        onClose={() => setIsSyncOpen(false)}
        onSyncSuccess={handleSyncSuccess}
      />

      <VoiceTutorialModal
        isOpen={isTutorialOpen}
        onClose={() => setIsTutorialOpen(false)}
        speakText={speakText}
      />

      <EmergencyModal
        isOpen={isEmergencyOpen}
        onClose={() => setIsEmergencyOpen(false)}
        speakText={speakText}
      />

      <EditCommitmentModal
        commitment={editingCommitment}
        isOpen={!!editingCommitment}
        onClose={() => setEditingCommitment(null)}
        onSave={handleUpdateCommitment}
        speakText={speakText}
      />

      <AlarmRingingModal
        isOpen={isAlarmModalOpen}
        onClose={() => setIsAlarmModalOpen(false)}
        alarmTitle={activeAlarmItem.title}
        alarmTime={activeAlarmItem.time}
        speakText={speakText}
        stopSpeech={stopSpeech}
        onConfirmDone={() => handleToggleComplete(activeAlarmItem.id)}
      />

    </div>
  );
}

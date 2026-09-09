import React, { useState } from 'react';
import { X, Calendar, CheckCircle2, RefreshCw } from 'lucide-react';

interface CalendarSyncModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSyncSuccess: (count: number) => void;
}

export const CalendarSyncModal: React.FC<CalendarSyncModalProps> = ({ isOpen, onClose, onSyncSuccess }) => {
  const [syncing, setSyncing] = useState(false);
  const [synced, setSynced] = useState(false);

  if (!isOpen) return null;

  const handleSyncGoogle = () => {
    setSyncing(true);
    setTimeout(() => {
      setSyncing(false);
      setSynced(true);
      onSyncSuccess(3); // Imported 3 simulated events
    }, 1800);
  };

  const handleSyncApple = () => {
    setSyncing(true);
    setTimeout(() => {
      setSyncing(false);
      setSynced(true);
      onSyncSuccess(2); // Imported 2 simulated events
    }, 1800);
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
      <div className="bg-white rounded-3xl max-w-lg w-full p-6 sm:p-8 shadow-2xl border-4 border-indigo-500 animate-in fade-in zoom-in-95 duration-200">
        
        <div className="flex items-center justify-between pb-4 border-b">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-indigo-100 text-indigo-700 rounded-2xl">
              <Calendar className="w-7 h-7" />
            </div>
            <div>
              <h3 className="text-xl font-black text-slate-900">Sincronizar Calendários</h3>
              <p className="text-xs font-medium text-slate-500">Google Calendar & Apple iCal</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2.5 bg-slate-100 hover:bg-red-100 text-slate-700 hover:text-red-700 rounded-full transition-colors cursor-pointer"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="py-6 space-y-6">
          <p className="text-base text-slate-600 leading-relaxed">
            Importe automaticamente consultas médicas e compromissos salvos no seu celular ou conta Google para que a 
            <strong> Agenda Amiga</strong> avise você em voz alta na hora certa.
          </p>

          {synced ? (
            <div className="bg-emerald-50 border border-emerald-200 p-4 rounded-2xl text-center space-y-2">
              <CheckCircle2 className="w-10 h-10 text-emerald-600 mx-auto" />
              <h4 className="font-bold text-emerald-900 text-lg">Sincronização Concluída!</h4>
              <p className="text-sm text-emerald-700">Seus compromissos externos foram importados com sucesso para a agenda por voz.</p>
            </div>
          ) : (
            <div className="space-y-3">
              <button
                onClick={handleSyncGoogle}
                disabled={syncing}
                className="w-full py-4 px-6 bg-white hover:bg-slate-50 border-2 border-slate-200 hover:border-indigo-500 rounded-2xl flex items-center justify-between font-bold text-slate-800 transition-all cursor-pointer shadow-sm"
              >
                <div className="flex items-center gap-3">
                  <span className="text-2xl">📅</span>
                  <div className="text-left">
                    <p className="text-lg">Conectar Google Calendar</p>
                    <p className="text-xs font-normal text-slate-500">Sincronizar eventos da conta Google</p>
                  </div>
                </div>
                {syncing ? <RefreshCw className="w-6 h-6 text-indigo-600 animate-spin" /> : <span className="text-indigo-600 font-bold">Conectar</span>}
              </button>

              <button
                onClick={handleSyncApple}
                disabled={syncing}
                className="w-full py-4 px-6 bg-white hover:bg-slate-50 border-2 border-slate-200 hover:border-indigo-500 rounded-2xl flex items-center justify-between font-bold text-slate-800 transition-all cursor-pointer shadow-sm"
              >
                <div className="flex items-center gap-3">
                  <span className="text-2xl">🍏</span>
                  <div className="text-left">
                    <p className="text-lg">Conectar Apple Calendar (iCal)</p>
                    <p className="text-xs font-normal text-slate-500">Sincronizar eventos do iPhone / iCloud</p>
                  </div>
                </div>
                {syncing ? <RefreshCw className="w-6 h-6 text-indigo-600 animate-spin" /> : <span className="text-indigo-600 font-bold">Conectar</span>}
              </button>
            </div>
          )}
        </div>

        <div className="pt-4 border-t flex justify-end">
          <button
            onClick={onClose}
            className="px-6 py-3 bg-indigo-600 hover:bg-indigo-700 text-white font-bold rounded-2xl shadow transition-all cursor-pointer"
          >
            Concluir
          </button>
        </div>

      </div>
    </div>
  );
};

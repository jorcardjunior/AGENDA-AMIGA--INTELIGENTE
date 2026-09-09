import React, { useState } from 'react';
import { X, PhoneCall, Heart, Send, CheckCircle2 } from 'lucide-react';

interface EmergencyModalProps {
  isOpen: boolean;
  onClose: () => void;
  speakText: (text: string) => void;
}

export const EmergencyModal: React.FC<EmergencyModalProps> = ({ isOpen, onClose, speakText }) => {
  const [sent, setSent] = useState(false);
  const [caregiverPhone, setCaregiverPhone] = useState('(11) 99888-7766');
  const [caregiverName, setCaregiverName] = useState('Maria (Filha)');

  if (!isOpen) return null;

  const handleAlert = () => {
    setSent(true);
    speakText(`Mensagem de aviso enviada para ${caregiverName}. Ela ligará em instantes.`);
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
      <div className="bg-white rounded-3xl max-w-md w-full p-6 sm:p-8 shadow-2xl border-4 border-red-500 animate-in fade-in zoom-in-95 duration-200 text-center">
        
        <div className="flex justify-end pb-2">
          <button
            onClick={onClose}
            className="p-2.5 bg-slate-100 hover:bg-red-100 text-slate-700 hover:text-red-700 rounded-full transition-colors cursor-pointer"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="w-20 h-20 bg-red-100 text-red-600 rounded-full flex items-center justify-center mx-auto mb-4 shadow-inner">
          <PhoneCall className="w-10 h-10 animate-bounce" />
        </div>

        <h3 className="text-2xl font-black text-slate-900 mb-1">Contato com Familiar / Cuidador</h3>
        <p className="text-sm text-slate-500 mb-6">
          Precisa de ajuda ou quer avisar que esqueceu de algo? Envie um sinal rápido ou ligue.
        </p>

        {sent ? (
          <div className="bg-emerald-50 border border-emerald-200 p-5 rounded-2xl space-y-2 mb-6">
            <CheckCircle2 className="w-10 h-10 text-emerald-600 mx-auto" />
            <h4 className="font-bold text-emerald-900 text-lg">Aviso Enviado com Sucesso!</h4>
            <p className="text-sm text-emerald-700">
              {caregiverName} recebeu uma notificação urgente no celular dela.
            </p>
          </div>
        ) : (
          <div className="space-y-4 mb-6">
            <div className="bg-slate-50 p-4 rounded-2xl border text-left">
              <span className="text-xs uppercase font-bold text-slate-400">Cuidador Cadastrado</span>
              <p className="text-lg font-black text-slate-800">{caregiverName}</p>
              <p className="text-sm font-semibold text-emerald-600">{caregiverPhone}</p>
            </div>

            <button
              onClick={handleAlert}
              className="w-full py-4 bg-red-600 hover:bg-red-700 text-white font-black text-lg rounded-2xl shadow-lg transition-all flex items-center justify-center gap-2 cursor-pointer"
            >
              <Send className="w-6 h-6" />
              <span>Chamar / Enviar SOS Agora</span>
            </button>
          </div>
        )}

        <button
          onClick={onClose}
          className="px-6 py-3 bg-slate-200 hover:bg-slate-300 text-slate-700 font-bold rounded-2xl transition-all cursor-pointer w-full"
        >
          Fechar
        </button>

      </div>
    </div>
  );
};

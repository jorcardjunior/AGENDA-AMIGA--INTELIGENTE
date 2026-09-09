import React from 'react';
import { X, FileText, CheckCircle2, ShieldAlert, Sparkles, Mic, Eye, HeartHandshake } from 'lucide-react';

interface TechnicalReportModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const TechnicalReportModal: React.FC<TechnicalReportModalProps> = ({ isOpen, onClose }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
      <div className="bg-white rounded-3xl max-w-4xl w-full max-h-[90vh] overflow-y-auto shadow-2xl border-4 border-emerald-500 p-6 md:p-8 animate-in fade-in zoom-in-95 duration-200">
        
        {/* Header */}
        <div className="flex items-center justify-between pb-6 border-b-2 border-emerald-100">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-emerald-100 text-emerald-700 rounded-2xl">
              <FileText className="w-8 h-8" />
            </div>
            <div>
              <span className="text-xs uppercase tracking-wider font-bold text-emerald-600 bg-emerald-50 px-2.5 py-1 rounded-full">
                Relatório Técnico & Análise de Usabilidade
              </span>
              <h2 className="text-2xl md:text-3xl font-black text-slate-800 mt-1">
                Agenda Inteligente Acessível (Projeto SeniorCare Voice)
              </h2>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-3 bg-slate-100 hover:bg-red-100 text-slate-700 hover:text-red-700 rounded-full transition-colors cursor-pointer"
            aria-label="Fechar relatório"
          >
            <X className="w-7 h-7" />
          </button>
        </div>

        {/* Content Body */}
        <div className="space-y-8 mt-6 text-slate-700">

          {/* Executive Summary */}
          <section className="bg-emerald-50/70 p-6 rounded-2xl border border-emerald-200">
            <h3 className="text-xl font-bold text-emerald-900 flex items-center gap-2 mb-2">
              <HeartHandshake className="w-6 h-6 text-emerald-700" />
              1. Sumário Executivo e Missão
            </h3>
            <p className="text-lg leading-relaxed text-slate-700">
              Este relatório apresenta a arquitetura e diretrizes de usabilidade para o desenvolvimento de uma 
              agenda 100% controlada por voz e adaptada para idosos e pessoas com esquecimento frequente ou baixa afinidade tecnológica. 
              O objetivo é eliminar barreiras digitais através de comandos de voz naturais, correção inteligente de horários confusos 
              e feedback multissensorial (voz, som e push em tempo real).
            </p>
          </section>

          {/* Accessibility & Usability Improvements */}
          <section className="space-y-4">
            <h3 className="text-xl font-bold text-slate-900 flex items-center gap-2 border-b pb-2">
              <Eye className="w-6 h-6 text-emerald-600" />
              2. Recomendações de Usabilidade e Acessibilidade Específicas
            </h3>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="bg-slate-50 p-5 rounded-2xl border border-slate-200">
                <h4 className="font-bold text-slate-800 text-lg mb-2 flex items-center gap-2">
                  <CheckCircle2 className="w-5 h-5 text-emerald-600" />
                  Interface Minimalista & Botões Gigantes
                </h4>
                <p className="text-base text-slate-600">
                  Eliminação completa de menus complexos e submenus aninhados. Todos os alvos de toque possuem dimensões mínimas de 
                  64x64px com espaçamento generoso para evitar toques acidentais por tremores ou baixa coordenação motora.
                </p>
              </div>

              <div className="bg-slate-50 p-5 rounded-2xl border border-slate-200">
                <h4 className="font-bold text-slate-800 text-lg mb-2 flex items-center gap-2">
                  <Mic className="w-5 h-5 text-emerald-600" />
                  Navegação e Comando 100% por Voz
                </h4>
                <p className="text-base text-slate-600">
                  O usuário pode falar naturalmente (ex: <em>"Lembrar de tomar o remedinho de pressão às 3 da tarde"</em>). O sistema 
                  interpreta e corrige automaticamente inversões de horário (ex: AM/PM) e confirma em voz alta com tom acolhedor.
                </p>
              </div>

              <div className="bg-slate-50 p-5 rounded-2xl border border-slate-200">
                <h4 className="font-bold text-slate-800 text-lg mb-2 flex items-center gap-2">
                  <ShieldAlert className="w-5 h-5 text-emerald-600" />
                  Priorização Inteligente de Tarefas
                </h4>
                <p className="text-base text-slate-600">
                  Classificação automática em 3 níveis visuais e sonoros: <strong>🔴 Alta (Saúde/Remédios)</strong>, 
                  <strong>🟡 Média (Consultas/Família)</strong> e <strong>🟢 Baixa (Rotina Casa)</strong>, destacando o mais urgente no topo.
                </p>
              </div>

              <div className="bg-slate-50 p-5 rounded-2xl border border-slate-200">
                <h4 className="font-bold text-slate-800 text-lg mb-2 flex items-center gap-2">
                  <Sparkles className="w-5 h-5 text-emerald-600" />
                  Sincronização com Calendários Existentes
                </h4>
                <p className="text-base text-slate-600">
                  Integração nativa com Google Calendar e Apple Calendar para unificar compromissos médicos e familiares já cadastrados 
                  pela família sem esforço do usuário final.
                </p>
              </div>
            </div>
          </section>

          {/* Gamification Ideas for Elderly Engagement */}
          <section className="bg-amber-50/70 p-6 rounded-2xl border border-amber-200">
            <h3 className="text-xl font-bold text-amber-900 flex items-center gap-2 mb-3">
              <Sparkles className="w-6 h-6 text-amber-600" />
              3. Ideias Criativas para Gamificação e Engajamento de Idosos
            </h3>
            <p className="text-base text-slate-700 mb-4">
              Para idosos, a gamificação não deve ser competitiva ou estressante, mas sim focada em <strong>gratificação emocional, 
              progresso visual e conexão afetiva</strong>:
            </p>

            <ul className="space-y-3 text-base text-slate-700 list-disc pl-5">
              <li>
                <strong>O Jardim da Vida (Orchards & Blooming):</strong> Cada tarefa cumprida ou remédio tomado no horário correto rega 
                uma plantinha virtual. Conforme os dias passam, flores coloridas desabrocham e árvores dão frutos virtuais (maçãs, laranjas).
              </li>
              <li>
                <strong>Mensagens de Voz Carinhosas da Família:</strong> Ao atingir 100% das tarefas do dia, o aplicativo reproduz 
                um áudio gravado carinhoso de um filho ou neto (ex: <em>"Parabéns vovô, orgulho de você!"</em>).
              </li>
              <li>
                <strong>Troféus de Superação Simples:</strong> Distintivos grandes e brilhantes com design nostálgico (ex: "Guardião da Saúde", 
                "Campeão da Pontualidade") com explicações em áudio quando conquistados.
              </li>
              <li>
                <strong>Sequência de Dias Felizes (Streak):</strong> Um contador alegre de dias seguidos cumprindo a rotina, representado 
                por um sol sorridente que brilha cada vez mais forte.
              </li>
            </ul>
          </section>

          {/* New Section: Offline AI & Natural Voice Libraries */}
          <section className="bg-sky-50/70 p-6 rounded-2xl border border-sky-200 space-y-4">
            <h3 className="text-xl font-bold text-sky-900 flex items-center gap-2">
              <Mic className="w-6 h-6 text-sky-700" />
              4. Tecnologias de IA Offline e Vozes Neurais Humanizadas (GitHub / Open Source)
            </h3>
            <p className="text-base text-slate-700 leading-relaxed">
              Para garantir que a agenda funcione com inteligência máxima mesmo sem internet (offline) em dispositivos Android e iOS, 
              bem como proporcionar uma experiência sonora natural e humanizada, recomendamos a adoção das seguintes tecnologias de ponta do ecossistema Open Source:
            </p>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
              <div className="bg-white p-4 rounded-xl border border-sky-100 shadow-sm">
                <h4 className="font-bold text-sky-900 text-base mb-1">🤖 ONNX Runtime + Transformers.js (IA Offline)</h4>
                <p className="text-sm text-slate-600">
                  Permite rodar modelos compactos de linguagem (SLMs como Phi-3-mini ou parsers quantizados) diretamente no dispositivo móvel 
                  (via WebView ou app nativo) para interpretar comandos de voz e linhas de tempo sem enviar dados para a nuvem.
                </p>
              </div>

              <div className="bg-white p-4 rounded-xl border border-sky-100 shadow-sm">
                <h4 className="font-bold text-sky-900 text-base mb-1">🗣️ Piper TTS / Sherpa-onnx (Voz 100% Offline & Natural)</h4>
                <p className="text-sm text-slate-600">
                  Biblioteca do GitHub extremamente rápida e otimizada para dispositivos móveis que gera síntese de voz (Text-to-Speech) neural 
                  em português do Brasil com entonação humana natural, sem travamentos e sem necessidade de conexão com a internet.
                </p>
              </div>

              <div className="bg-white p-4 rounded-xl border border-sky-100 shadow-sm">
                <h4 className="font-bold text-sky-900 text-base mb-1">⏰ Background Workers & AlarmManager (Android/iOS)</h4>
                <p className="text-sm text-slate-600">
                  Uso de APIs nativas de agendamento de alarmes e notificações locais push em tempo real (Flutter/React Native background sync) 
                  garantindo que o aviso sonoro do remédio toque exatamente no horário exato, mesmo com o celular no bolso ou tela bloqueada.
                </p>
              </div>

              <div className="bg-white p-4 rounded-xl border border-sky-100 shadow-sm">
                <h4 className="font-bold text-sky-900 text-base mb-1">📅 SQLite Local + Ferramentas de Fuso Horário</h4>
                <p className="text-sm text-slate-600">
                  Banco de dados local ultra-rápido para persistir compromissos recorrentes ("a cada 3 dias", "toda hora") mantendo a consistência 
                  de datas e horários em qualquer lugar do mundo.
                </p>
              </div>
            </div>
          </section>

          {/* Conclusion */}
          <div className="pt-4 border-t flex items-center justify-between">
            <span className="text-sm font-medium text-slate-500">
              Relatório compilado para validação de acessibilidade e protótipo funcional.
            </span>
            <button
              onClick={onClose}
              className="px-6 py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-2xl shadow-lg transition-all cursor-pointer"
            >
              Entendido, Voltar à Agenda
            </button>
          </div>

        </div>

      </div>
    </div>
  );
};

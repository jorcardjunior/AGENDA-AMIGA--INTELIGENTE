# 📘 DOCUMENTAÇÃO COMPLETA DE REPRODUÇÃO - AGENDA INTELIGENTE ACESSÍVEL (SENIORCARE VOICE)
> **Autor do Projeto / Créditos:** JORCARD_JR  
> **Versão:** 2.0.0 (Produção Full-Stack + Flutter Companion Nativo)  
> **Propósito deste Documento:** Guia mestre definitivo passo a passo para que qualquer Inteligência Artificial (IA) ou desenvolvedor reproduza **com exatidão cirúrgica** todas as funções, arquitetura, design, UI/UX, animações, lógica de voz, alarmes e módulos nativos criados neste projeto.

---

## 📑 ÍNDICE GERAL
1. [Visão Geral e Objetivos do Projeto](#1-visão-geral-e-objetivos-do-projeto)
2. [Arquitetura Geral do Sistema e Tecnologias](#2-arquitetura-geral-do-sistema-e-tecnologias)
3. [Estrutura Completa de Diretórios e Arquivos](#3-estrutura-completa-de-diretórios-e-arquivos)
4. [Dependências e Configurações (package.json, tsconfig, vite)](#4-dependências-e-configurações)
5. [Modelo de Dados & Tipagem TypeScript (src/types.ts)](#5-modelo-de-dados--tipagem-typescript)
6. [Backend e Inteligência Artificial Gemini (server.ts)](#6-backend-e-inteligência-artificial-gemini)
7. [Módulo de Reconhecimento e Síntese de Voz (Anti-Eco Cirúrgico)](#7-módulo-de-voz-e-síntese-auditiva)
8. [Parser de Linguagem Natural Brasileiro Offline (src/utils/naturalParser.ts)](#8-parser-natural-pt-br-offline)
9. [Motor de Alarmes e Lógica em Segundo Plano 24h](#9-motor-de-alarmes-em-segundo-plano-24h)
10. [Interface de Usuário (UI/UX) e Acessibilidade para Idosos](#10-interface-de-usuário-uiux-e-acessibilidade)
11. [Detalhamento Completo de Cada Componente React](#11-detalhamento-de-cada-componente-react)
12. [Módulo Nativo Companion em Flutter (Android & iOS)](#12-módulo-nativo-companion-em-flutter)
13. [Guia Passo a Passo de Reprodução para Novas IAs](#13-guia-passo-a-passo-de-reprodução)

---

## 1. VISÃO GERAL E OBJETIVOS DO PROJETO

A **Agenda Amiga / Agenda Inteligente Acessível** foi desenvolvida para resolver uma das dores mais críticas de pessoas idosas ou com déficit de memória/atenção: **o esquecimento de medicações diárias, consultas médicas e tarefas rotineiras**, combinado com a **dificuldade de lidar com interfaces digitais tradicionais cheias de menus complexos e letras pequenas**.

### Pilares Fundamentais:
1. **Comando e Navegação 100% por Voz:** O usuário pode falar naturalmente (ex: *"Tomar meu remédio de pressão às 8 horas da manhã todos os dias"*). O sistema processa o texto, corrige erros de horário ou ordem de palavras e confirma em voz alta com tom acolhedor.
2. **Confirmação em 2 Passos por Voz ("Sim" / "Não"):** Evita agendamentos acidentais. A agenda ouve o que o usuário disse, pergunta confirmando o horário e só grava se o usuário responder "Sim", "Ok" ou tocar no botão de confirmação.
3. **Alarmes Ativos 24h em Segundo Plano com Desligamento por Voz:** O sistema monitora o relógio a cada 10 segundos. No horário do compromisso, dispara um modal vermelho com vibração háptica contínua e anúncio sonoro em voz alta. O idoso pode silenciar o alarme apenas dizendo *"Desligar"*, *"Já tomei"* ou *"Ok"*.
4. **Design Ergonômico e Acessibilidade Senior:**
   - Botões gigantes (mínimo de 64x64px até 144x144px no microfone central).
   - Tipografia de altíssimo contraste (Slate 900 sobre fundo off-white/esmeralda).
   - Calendário semanal com botões de dias largos e contadores de tarefas.
   - Alternador de tela cheia vs. Simulador de Celular Smartphone.
   - Botão de Emergência SOS direto para cuidador/familiar com discagem rápida e mensagem push.
   - Resumo do Dia por IA (Briefing diário falado com saudações e dicas de saúde).

---

## 2. ARQUITETURA GERAL DO SISTEMA E TECNOLOGIAS

### Stack Tecnológica:
- **Frontend SPA:** React 19, TypeScript (~5.8), Vite 6.
- **Estilização & Design System:** Tailwind CSS v4 (`@tailwindcss/vite`), paleta centrada em Esmeralda (`#059669`), Slate neutro e alertas em Vermelho/Âmbar.
- **Ícones do Sistema:** `lucide-react` (ícones expressivos e padronizados).
- **Backend Servidor:** Node.js + Express 4.21, integrado como middleware do Vite via `server.ts`.
- **Inteligência Artificial em Nuvem:** Google Gemini 2.5 Flash via `@google/genai` (SDK oficial) para interpretação cirúrgica de comandos de voz e geração de briefings diários de saúde.
- **Processamento de Voz Local:** Web Speech API (`SpeechRecognition` / `webkitSpeechRecognition` para fala-para-texto e `SpeechSynthesis` para texto-para-fala).
- **Parser Offline Local:** Expressões Regulares customizadas em TypeScript para operar mesmo sem internet ou sem chave de API Gemini.
- **Persistência de Dados:** `localStorage` resiliente com auto-salvamento e sincronização de eventos.
- **Versão Mobile Nativa:** Flutter 3.x com `flutter_tts`, `flutter_local_notifications` e `shared_preferences`.

---

## 3. ESTRUTURA COMPLETA DE DIRETÓRIOS E ARQUIVOS

```text
/
├── .env.example                               # Exemplo de chaves (GEMINI_API_KEY, APP_URL)
├── .gitignore                                 # Ignora node_modules, dist, etc.
├── index.html                                 # Ponto de entrada HTML com meta tags e títulos acessíveis
├── metadata.json                              # Configuração de capacidades e permissões de iframe
├── package.json                               # Dependências e scripts dev/build/start
├── server.ts                                  # Servidor Express com rotas de IA Gemini e Vite middleware
├── tsconfig.json                              # Configuração do TypeScript compiler
├── vite.config.ts                             # Configuração do Vite com plugins React e Tailwind CSS
├── public/
│   └── assets/aistudio/
├── flutter/                                   # APP NATIVO FLUTTER PARA SMARTPHONES (ANDROID/IOS)
│   ├── README_FLUTTER.md                      # Instruções de compilação do APK nativo
│   ├── pubspec.yaml                           # Dependências do Flutter
│   └── lib/
│       ├── main.dart                          # App Flutter completo com UI e TTS
│       ├── models/commitment.dart             # Model de dados no Flutter
│       ├── parser/brazilian_natural_time_parser.dart # Parser regex offline em Dart
│       └── services/notification_service.dart # Serviço de agendamento de notificações nativas
└── src/                                       # CÓDIGO-FONTE PRINCIPAL REACT + TYPESCRIPT
    ├── main.tsx                               # Entrada do React (StrictMode + createRoot)
    ├── App.tsx                                # Componente raiz, gerenciador de estado e loop de alarme
    ├── index.css                              # Import do Tailwind CSS (@import "tailwindcss";)
    ├── types.ts                               # Interfaces globais TypeScript
    ├── components/
    │   ├── Header.tsx                         # Barra superior com ações (Resumo, SOS, Sincronização)
    │   ├── VoiceCommandAssistant.tsx          # Microfone gigante, transcrição e fluxo "Sim/Não"
    │   ├── WeeklyCalendar.tsx                 # Calendário de 7 dias com badges e leitura por voz
    │   ├── CommitmentList.tsx                 # Lista filtrável com badges de prioridade e check
    │   ├── AlarmRingingModal.tsx              # Modal de alarme em tempo real com escuta por voz
    │   ├── CalendarSyncModal.tsx              # Sincronização com Google Calendar / Apple iCal
    │   ├── EmergencyModal.tsx                 # Contato rápido de emergência com o cuidador
    │   ├── EditCommitmentModal.tsx            # Edição manual completa do compromisso
    │   ├── VoiceTutorialModal.tsx             # Tutorial ilustrado de como falar com a agenda
    │   └── TechnicalReportModal.tsx           # Relatório de usabilidade, métricas e gamificação sênior
    └── utils/
        ├── dateFormatter.ts                   # Formatadores de data amigável em português
        ├── naturalParser.ts                   # Parser Regex offline para horário, data e categoria
        └── speech.ts                          # Wrapper de síntese de voz (TTS) humanizada em pt-BR
```

---

## 4. DEPENDÊNCIAS E CONFIGURAÇÕES

### `package.json`
```json
{
  "name": "remix-agenda-inteligente-acessivel",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "tsx server.ts",
    "build": "vite build && esbuild server.ts --bundle --platform=node --format=cjs --packages=external --sourcemap --outfile=dist/server.cjs",
    "start": "node dist/server.cjs"
  },
  "dependencies": {
    "@google/genai": "^2.4.0",
    "@tailwindcss/vite": "^4.1.14",
    "@vitejs/plugin-react": "^5.0.4",
    "dotenv": "^17.2.3",
    "express": "^4.21.2",
    "lucide-react": "^0.546.0",
    "motion": "^12.23.24",
    "react": "^19.0.1",
    "react-dom": "^19.0.1",
    "vite": "^6.2.3"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/node": "^22.14.0",
    "autoprefixer": "^10.4.21",
    "esbuild": "^0.25.0",
    "tailwindcss": "^4.1.14",
    "tsx": "^4.21.0",
    "typescript": "~5.8.2"
  }
}
```

### `vite.config.ts`
```typescript
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import { defineConfig } from 'vite';

export default defineConfig(() => {
  return {
    plugins: [react(), tailwindcss()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, '.'),
      },
    },
    server: {
      hmr: process.env.DISABLE_HMR !== 'true',
      watch: process.env.DISABLE_HMR === 'true' ? null : {},
    },
  };
});
```

---

## 5. MODELO DE DADOS & TIPAGEM TYPESCRIPT

### Arquivo: `/src/types.ts`
```typescript
export interface Commitment {
  id: string;
  title: string;
  date: string; // Formato YYYY-MM-DD
  time: string; // Formato HH:MM
  priority: 'Alta' | 'Média' | 'Baixa';
  category: 'Saúde/Remédio' | 'Família' | 'Consulta' | 'Casa' | 'Outros';
  completed: boolean;
  correctionNote?: string;
  reminderMinutesBefore?: number;
  recurrence?: string; // "Todos os dias", "A cada 3 dias", "A cada hora", "Único", "Semanal"
}
```

---

## 6. BACKEND E INTELIGÊNCIA ARTIFICIAL GEMINI

O servidor Express (`/server.ts`) inicializa na porta `3000` (obrigatória para containers) e expõe dois endpoints cruciais protegendo a chave de API no servidor:

### 1. Endpoint `/api/parse-voice` (POST)
- **Recebe:** `{ transcript: string, currentDateTime: string }`
- **Função:** Envia um prompt contextualizado para o modelo `gemini-2.5-flash` instruindo-o a:
  - Agir como assistente de voz cirúrgico para idosos.
  - Detectar a intenção mesmo se a ordem de fala estiver embaralhada (ex: *"Às 3 da tarde tomar o remédio de pressão Losartana"*).
  - Corrigir confusões temporais absurdas (ex: se o usuário disser *"3 da manhã"* para consulta de rotina, ajustar para *"15:00"* e justificar em `correctionNote`).
  - Identificar recorrências complexas.
  - Retornar uma frase calorosa em `spokenConfirmation` pronta para ser lida em voz alta.
- **Fallback:** Caso não haja chave configurada ou ocorra erro de rede, o endpoint responde com valores padrão coerentes sem quebrar a aplicação.

### 2. Endpoint `/api/briefing` (POST)
- **Recebe:** `{ tasks: Commitment[] }`
- **Função:** Analisa os compromissos do dia do usuário e gera uma saudação carinhosa e motivadora com 2 dicas práticas de saúde geriátrica (ex: hidratação, caminhada leve).

### 3. Integração do Vite Middleware
Em desenvolvimento, o servidor usa `createViteServer({ server: { middlewareMode: true }, appType: 'spa' })` montando os middlewares após as rotas de API. Em produção, entrega os arquivos estáticos da pasta `dist/`.

---

## 7. MÓDULO DE VOZ E SÍNTESE AUDITIVA

### Arquivo: `/src/utils/speech.ts`
Contém as funções `speakHumanVoice` e `stopHumanVoice` configuradas com:
- `utterance.lang = 'pt-BR'`
- `utterance.rate = 0.92` (fala ligeiramente mais cadenciada e pausada, ideal para compreensão por idosos).
- `utterance.pitch = 1.0`
- **Seleção Inteligente de Voz:** Varre as vozes disponíveis no navegador dando preferência àquelas contendo `google`, `natural`, `microsoft` ou `luciana` em português do Brasil.

### 🛡️ Arquitetura Anti-Eco Cirúrgica (Anti-Self-Triggering)
Um dos problemas mais comuns em interfaces de voz é o microfone capturar o áudio que a própria aplicação está reproduzindo pelo alto-falante. No projeto, isso foi resolvido da seguinte forma:
1. Ao falar qualquer texto, a síntese de voz dispara com callbacks `onStart` e `onEnd`.
2. O microfone é mantido **desligado** durante a reprodução.
3. **Somente após a finalização completa do áudio (`onEnd`)**, o reconhecimento de voz (`SpeechRecognition`) é acionado para ouvir a resposta do usuário ("Sim", "Não", "Desligar", etc.).

---

## 8. PARSER NATURAL PT-BR OFFLINE

### Arquivo: `/src/utils/naturalParser.ts`
Garante que a aplicação seja **100% funcional mesmo sem internet**:
1. **Detecção de Categorias e Prioridade:**
   - Palavras como *remédio, medicamento, comprimido, gota, pressão* -> Categoria `Saúde/Remédio`, Prioridade `Alta`.
   - Palavras como *consulta, médico, doutor, exame, hospital* -> Categoria `Consulta`, Prioridade `Alta`.
   - Palavras como *filho, filha, neto, família, esposa* -> Categoria `Família`, Prioridade `Média`.
   - Palavras como *casa, água, luz, mercado, comida* -> Categoria `Casa`, Prioridade `Média`.
2. **Detecção de Recorrência:**
   - *de hora em hora, a cada 2 horas, todos os dias, a cada 3 dias, semanal*.
3. **Cálculo de Horários:**
   - Expressões como *"daqui a 15 minutos"* adicionam minutos ao horário atual.
   - Expressões com *"às 8:30"*, *"as 14h"*, *"8 da noite"* ajustam horas e convertem turnos (adicionando +12h se noite/tarde).
   - Menção a *"amanhã"* avança o dia no calendário.

---

## 9. MOTOR DE ALARMES EM SEGUNDO PLANO 24H

No componente raiz `App.tsx`:
- Um `useEffect` executa um `setInterval` a cada **10 segundos** verificando os compromissos armazenados.
- Compara a data de hoje (`YYYY-MM-DD`) e o horário atual (`HH:MM`).
- Se houver compromisso pendente com horário coincidente (ou com recorrência `"Todos os dias"`), o alarme é disparado abrindo o `AlarmRingingModal`.
- **Efeitos do Alarme Ativo:**
  1. Vibração repetida via `navigator.vibrate([500, 200, 500, 200, 500, 200, 500])`.
  2. Modal em tela cheia com fundo vermelho escuro e borda de 4px vermelha pulsante.
  3. Fala em voz alta o nome do remédio ou compromisso.
  4. Ativa o microfone após o anúncio e escuta palavras-chave como *"desligar"*, *"já ouvi"*, *"ok"*, *"tomei"*, *"parar"* para marcar automaticamente como concluído e silenciar.
  5. Oferece botões grandes: **"Já Tomei / Realizei!"** (verde esmeralda) e **"Adiar por 10 Minutos"** (âmbar).

---

## 10. INTERFACE DE USUÁRIO (UI/UX) E ACESSIBILIDADE

O design foi concebido sob a filosofia **Anti-Slop & Senior First**:
- **Cores Semânticas Claras:**
  - Esmeralda (`#059669` / `bg-emerald-600`): Ação principal, saúde, confirmação, segurança.
  - Vermelho (`#DC2626` / `bg-red-600`): Urgência, alarme ativo, botão SOS / Emergência.
  - Âmbar (`#D97706` / `bg-amber-500`): Atenção, confirmação pendente, adiamento.
  - Slate Neutro (`#0F172A` a `#F8FAFC`): Contraste preto no branco impecável para fácil leitura.
- **Barra de Status do Dispositivo (topo):**
  - Mostra os badges: `🎙️ Mic Ativo`, `🔔 Alarmes 24h`, `📶 Online / Offline Seguro`.
  - Botão para alternar entre **Modo Tela Cheia** e **Simulador de Smartphone Celular** (com borda de dispositivo arredondada de 48px).
- **Rodapé Padronizado:**
  - "Agenda Amiga Protegida ❤️ Operação 24h (Offline & Background)"
  - **Crédito Exclusivo:** *"Desenvolvido por: JORCARD_JR"*.

---

## 11. DETALHAMENTO DE CADA COMPONENTE REACT

### 1. `Header.tsx`
- Logotipo com microfone animado e título "Agenda Amiga (Voz)".
- Botão "Ouvir Resumo" (chama `/api/briefing` e fala o bom dia com dicas).
- Botão "Parar Áudio" (aparece apenas quando a voz está ativa).
- Botão "Sincronizar" (abre `CalendarSyncModal`).
- Botão de Ajuda "?" (abre `VoiceTutorialModal`).
- Botão de Emergência Vermelho pulsante "Ajuda / Família" (abre `EmergencyModal`).

### 2. `VoiceCommandAssistant.tsx`
- Botão gigante de microfone (112px a 144px). Quando ouvindo, fica vermelho pulsante com ícone girando; quando ocioso, branco com anel verde e salto sutil (`animate-bounce`).
- Caixa de transcrição em tempo real mostrando as palavras faladas pelo idoso.
- Caixa de confirmação em 2 etapas: exibe o que a agenda entendeu e aguarda o usuário falar "Sim" ou "Não" (ou clicar nos botões verdes/vermelhos equivalentes).
- Campo alternativo de digitação rápida para cuidadores.

### 3. `WeeklyCalendar.tsx`
- Gera os 7 dias da semana atual a partir do domingo.
- Cada dia exibe: dia da semana (Dom, Seg, Ter...), número do dia do mês e contador circular com quantidade de tarefas pendentes.
- Ao clicar em um dia, a agenda fala em português natural: *"Segunda-feira, dia 7 de setembro de 2026. Você tem X compromissos."*.

### 4. `CommitmentList.tsx`
- Abas de filtro: "Todos", "Pendentes", "Feitos" com contadores.
- Itens da lista com:
  - Círculo de seleção grande para marcar como concluído (com efeito de riscado no texto).
  - Ícone emoji da categoria (💊 Remédio, 🩺 Consulta, 👨‍👩‍👧‍👦 Família, 🏠 Casa).
  - Badge de prioridade (Vermelho Alta, Amarelo Média, Verde Baixa).
  - Horário em destaque com ícone de relógio.
  - Nota explicativa caso tenha havido correção temporal de IA.
  - Botão de alto-falante para ler o compromisso individual em voz alta.
  - Botão de lápis para abrir edição.
  - Botão de lixeira para excluir com confirmação sonora.

### 5. `AlarmRingingModal.tsx`
- Modal modal de alta visibilidade com fundo translúcido escuro e caixa central com borda vermelha de 4px.
- Ícone de sino animado saltando.
- Leitura automática do nome do compromisso.
- Ativação de microfone para desligar por comando de voz.
- Botões de toque para ação imediata.

### 6. `EmergencyModal.tsx`
- Painel para contato rápido com o cuidador cadastrado (ex: "Maria - Filha - (11) 99888-7766").
- Botão "Chamar / Enviar SOS Agora" que confirma o envio sonoro imediato.

### 7. `CalendarSyncModal.tsx`
- Interface para conectar e importar consultas do Google Calendar e Apple iCal, simulando importação com feedback sonoro.

### 8. `VoiceTutorialModal.tsx`
- Tutorial visual com 4 passos simples explicando como falar, como ouvir e como responder "Sim/Não".

### 9. `EditCommitmentModal.tsx`
- Modal para alterar título, data, horário, prioridade, categoria e frequência de recorrência.

### 10. `TechnicalReportModal.tsx`
- Documento técnico interativo integrado no app com o sumário executivo, diretrizes de acessibilidade, ideias de gamificação sênior ("Jardim da Vida", áudios da família) e arquitetura offline.

---

## 12. MÓDULO NATIVO COMPANION EM FLUTTER

Localizado na pasta `/flutter`, permite gerar o aplicativo nativo para instalação direta no smartphone (Android APK / iOS IPA):

- **`pubspec.yaml`**: Dependências `flutter_tts`, `flutter_local_notifications`, `shared_preferences`.
- **`lib/main.dart`**: Implementa a interface completa em Flutter com AppBar verde escuro, barra de segurança offline 24h, campo de inserção com parser natural pt-BR, lista de cards com checkbox, reprodução em áudio e rodapé com a assinatura:
  ```dart
  // Desenvolvido por: JORCARD_JR
  ```
- **`lib/services/notification_service.dart`**: Configura o `FlutterLocalNotificationsPlugin` com canal de som de alarme em prioridade máxima (`Importance.max`, `Priority.high`) para tocar mesmo com tela bloqueada.
- **`lib/parser/brazilian_natural_time_parser.dart`**: Parser nativo em Dart com Regex para extrair horários e turnos da fala em português.

---

## 13. GUIA PASSO A PASSO DE REPRODUÇÃO

Caso outra IA ou desenvolvedor precise recriar este projeto do zero em um ambiente limpo:

### Passo 1: Inicialização do Workspace
```bash
npm init -y
npm install react react-dom express dotenv @google/genai lucide-react motion
npm install -D vite @vitejs/plugin-react @tailwindcss/vite tailwindcss typescript @types/react @types/react-dom @types/node @types/express tsx esbuild
```

### Passo 2: Configuração de Build e Dev
Configure o `package.json` com os scripts de build do esbuild para o `server.ts` conforme a Seção 4, e adicione `"@import "tailwindcss";"` no arquivo `/src/index.css`.

### Passo 3: Criação dos Modelos e Utilitários
1. Crie `/src/types.ts` com a interface `Commitment`.
2. Crie `/src/utils/speech.ts` com a lógica de voz pt-BR e controle de eco.
3. Crie `/src/utils/naturalParser.ts` com o extrator regex offline.
4. Crie `/src/utils/dateFormatter.ts` para converter datas ISO em português natural.

### Passo 4: Implementação dos Componentes
Crie os componentes de `/src/components/` seguindo as especificações de acessibilidade (botões grandes, contrastes altos, confirmação em 2 passos por voz).

### Passo 5: Implementação do Loop de Alarme no `App.tsx`
Implemente o `setInterval` de 10 segundos verificando hora e data atual para acionar o `AlarmRingingModal` com vibração e fala simultâneas.

### Passo 6: Backend Express + IA Gemini
Implemente o `/server.ts` com as rotas `/api/parse-voice` e `/api/briefing` usando o modelo `gemini-2.5-flash`, além da entrega estática do Vite.

### Passo 7: Módulo Flutter Opcional
Na pasta `/flutter`, replique o código do `main.dart` e configure as notificações locais para compilação via `flutter build apk --release`.

---
*Documentação oficial gerada para conformidade total de reprodução por IAs e Engenheiros de Software.*

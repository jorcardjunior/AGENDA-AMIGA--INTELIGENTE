# 📱 Agenda Inteligente Acessível (SeniorCare Voice)
> **Desenvolvido por:** JORCARD_JR  
> **Versão:** 2.0.0 (Web Full-Stack + Flutter Companion Nativo)

Agenda inteligente e acessível operada 100% por comandos de voz naturais, desenvolvida com foco prioritário em idosos, pessoas com esquecimento e cuidadores. Conta com alarmes em tempo real 24h, autocorreção de horários com Inteligência Artificial, interface de alto contraste com botões gigantes e modo offline resiliente.

---

## 📖 Documentação Completa de Reprodução

Para obter todos os detalhes técnicos, especificações de componentes, fluxos de UI/UX, arquitetura de voz anti-eco, endpoints da API Gemini e instruções passo a passo para que outras IAs ou desenvolvedores reproduzam a aplicação exatamente igual, consulte o arquivo mestre:

👉 **[DOCUMENTACAO_COMPLETA_REPRODUCAO.md](./DOCUMENTACAO_COMPLETA_REPRODUCAO.md)**

📝 **[MELHORIAS_LOG.md](./MELHORIAS_LOG.md)** — registro de todas as melhorias implementadas (alarme-despertador que acorda a tela, toque no modo silêncio, integração VoxSherpa offline, upgrades de dependências, e agora o **assistente de voz inteligente** que fala o compromisso com contexto, hora natural e bênção de Deus — sem repetir o texto digitado).

---

## 🚀 Como Executar o Projeto

### Pré-requisitos
- Node.js 18+ instalado
- (Opcional) Flutter SDK instalado caso deseje compilar o APK nativo

### Execução Web Full-Stack (React + Express + Gemini)
```bash
# Instalar dependências
npm install

# Iniciar servidor de desenvolvimento (Porta 3000)
npm run dev

# Compilar para produção
npm run build

# Iniciar build de produção
npm start
```

### Execução do Aplicativo Nativo Flutter (Smartphones Android/iOS)
```bash
cd flutter
flutter pub get
flutter run
# Para gerar o instalador APK para Android:
flutter build apk --release
```

---

## 🌟 Principais Recursos

- 🎙️ **Comando 100% por Voz & Confirmação em 2 Passos:** Fala natural com verificação do tipo *"Vou agendar seu remédio para às 8h. Diga Sim para confirmar ou Não para cancelar"*.
- ⏰ **Alarme Real 24h com Desligamento por Voz:** O alarme toca na hora certa, vibra o celular, fala o nome da tarefa e pode ser desligado apenas dizendo *"Desligar"*, *"Já tomei"* ou *"Ok"*.
- 🕑 **Qualquer Timeline por Voz:** "tomar água daqui 3 minutos", "daqui a 2 horas/dias", recorrência **mensal** ("reunião da empresa todo dia 10" — toca todo dia 10, mesmo mês curto) e **lembrete antecipado** ("me lembre 3 dias antes" — avisa e toca de novo no dia).
- 🤖 **IA Gemini 2.5 Flash + Parser Offline:** Corrige confusões de horário e gera resumos diários carinhosos com dicas de saúde geriátrica.
- 📱 **Simulador de Celular Embutido:** Permite testar a experiência exata de um smartphone diretamente pelo navegador.
- 🆘 **Botão de Emergência / Família:** Envio rápido de alerta e discagem direta para o cuidador cadastrado.
- 📅 **Calendário Semanal Falado:** Toque em qualquer dia da semana para ouvir os compromissos agendados.

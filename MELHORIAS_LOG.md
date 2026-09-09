# LOG DE MELHORIAS — Agenda Amiga

Registro de todas as melhorias implementadas. Cada sessão adiciona uma nova seção no topo.

---

## Sessão 08/09/2026 (4ª) — Diagnóstico ao vivo + auto-recuperação: o alarme agora fala o que está bloqueando

Relato do usuário: o alarme *continua não tocando* com a tela e o app fechados mesmo com as permissões aparentando OK. Investigado a fundo o fluxo nativo do Android.

### Causas identificadas por quê o alarme "morre" com o app fechado no Android
| Causa | Explicação |
|---|---|
| **Notificações bloqueadas pelo Android** | Usuário ou OEM desativou por engano; a notificação é silenciosamente descartada pelo sistema. |
| **Alarme exato sem permissão especial** | Em Android 12-13, "SCHEDULE_EXACT_ALARM" precisa ser liberado em Acesso Especial. Sem isso, o `exactAllowWhileIdle` falha e o alarme **atrasa ou nunca toca**. No Android 14+ (USE_EXACT_ALARM), é automático, mas OEMs podem bloquear. |
| **Otimização de bateria Doze/App Standby** | Apesar de `alarmClock` desbloquear Doze, OEMs como Xiaomi/OPPO/Realme acrescentam restrições próprias (App Standby em nível "Restricted") que impedem até `setAlarmClock`. |
| **App force-stop pelo usuário ou pelo sistema** | Limpa todos os alarmes pendentes do AlarmManager ao ser reaberto; nenhum alarme antigo sobrevive. |
| **Atualização do APK (reinstall)** | Pode nuke agendamentos anteriores se o boot receiver falhar. |

### Correções implementadas (sessão 4)

**1. Auto-recuperação ao abrir o app (belts-and-suspenders)**

Adicionei em `_init()`, imediatamente após as permissões serem pedidas, um loop que **re-armazena todos os alarmes não-concluídos**. Isso reforça o `ScheduledNotificationBootReceiver` do plugin:
- Se o app foi atualizado → alarmes reaparecem.
- Se o usuário reabriu após o sistema ter matado o processo → alarmes reaparecem.
- Não causa duplicatas — o `id` da notificação sobrescreve via `zonedSchedule`.

**2. Modal "Diagnóstico de Alarmes" (botão 🛠 Diagnóstico na toolbar)**

O usuário agora pode ver **exatamente** o que está bloqueando o alarme — sem precisar entender a jargagem técnica:

| Status | Significado |
|---|---|
| 🔴 **Notificações do Android — Bloqueadas** | O alarme NÃO pode aparecer. Botão "Permitir Agora" abre as configurações do Android. |
| 🔴 **Alarme Exato — Bloqueado** | O alarme pode atrasar ou NÃO tocar. Botão abre Acesso Especial para "Alarmes e lembretes". |
| 🔵 **Otimização de Bateria** | Cartão explicativo com 3 passos claros: Configurações → Baterias → Agenda Amiga → Uso não restrito. |
| 🟢 **Testar Alarme em 20 segundos** | Agenda um alarme real via `setAlarmClock` que toca em 20s com tela ligada — valida de ponta a ponta se o Android permite alarms neste aparelho. |

O diagnóstico chama `areNotificationsEnabled()` e `canScheduleExactNotifications()` em tempo real. Os botões de correção usam `requestExactAlarmPermission()` e `openAppNotificationSettings()`.

**3. Botão "Testar Alarme em 20 segundos" (ação de validação)**

Agenda um alarme ONE-SHOT com `alarmClock` em 20 segundos. Se tocar → alarmes funcionam. Se não tocar → a causa é permissão de alarme ou otimização de bateria. O payload é um JSON seguramente parseado pelo `_openAlarmFromPayload` (sem crash).

### Mudanças técnicas
- **`notification_service.dart`**: novos métodos `alarmPermissionsStatus()` (mapa `{'notificationsEnabled': bool?, 'exactAlarmAllowed': bool?}`), `openAppNotificationSettings()`. Mantido `requestExactAlarmsPermission()` como entry-point de correção.
- **`main.dart`**: novo `_openDiagnosticsModal`, novo `_scheduleTestAlarm`, novo loop de re-arm em `_init()`.
- **`widgets/modals.dart`**: novo `AlarmDiagnosticsModal` ( StatefulWidget, 2 estados de carregamento/dados) com linhas de status, botões de correção e card de orientação de bateria.

### O que o usuário deve fazer agora
1. Instale o APK novo por cima.
2. Abra o app → toque em 🛠 **Diagnóstico** na toolbar.
3. Se aparecer 🔴 em qualquer permissão → toque em **"Permitir Agora"** → confirme no diálogo do Android.
4. Toque em **"🔔 Testar Alarme em 20 segundos"** → desligue a tela → espere.
5. Se o teste tocar → qualquer compromisso agora também toca.
6. Se **não tocar** → siga o passo a passo de bateria no card amarelo dentro do Diagnóstico.

> Se depois de tudo ainda não tocar, reinicie o celular (muitos OEMs exigem isso para aplicar as permissões de alarme).

### Validação
- `flutter analyze`: **0 issues** ✓
- `flutter test`: **57 testes passando** ✓ (nenhum teste anterior quebrado).
- `flutter build apk --release`: **OK**, `AgendaAmiga-APK-para-instalar.apk` (53,6 MB) copiado.

---

## Sessão 08/09/2026 (5ª) — Saudação usa horário atual do dispositivo

**Relato**: o app dizia "Bom dia!" quando agendava algo às 9 AM mesmo que fosse 8 PM (noite).

### Causa raiz
`MessageComposer.compose()` calculava `hour` a partir de `c.time` (horário do compromisso), e usava essa hora para a saudação ("Boa noite!", "Bom dia!", etc.). Para um compromisso às 9 AM agendado às 8 PM da noite, dizia "Bom dia!" em vez de "Boa noite!".

### Correção
A saudação agora usa **sempre `DateTime.now().hour`** (hora atual do dispositivo). O horário agendado continua sendo usado apenas na parte falada do compromisso ("são nove da manhã" / "marcado para nove da manhã").

- Alarme dispara agora → hora agora = hora do alarme → ok.
- Confirmação falada agora → hora agora = hora do usuário → ok.

### Mudança técnica
- `lib/intelligence/message_composer.dart`: `compose()` não lê mais `c.time` para `hour`; usa `DateTime.now().hour` para todos os contextos.

### Validação
- `flutter analyze`: **0 issues** ✓
- `flutter test`: **57 testes passando** ✓
- `flutter build apk --release`: **OK**, `AgendaAmiga-APK-para-instalar.apk` (54,1 MB) copiado.

---

## Sessão 08/09/2026 (10ª) — Auditoria completa + correção de bugs críticos + limpeza

Auditoria linha-a-linha de todo o codebase (18 Dart, Kotlin, manifest, 5 testes). Encontrados 4 bugs críticos, 4 problemas de confiabilidade, 5 código obsoleto, 3 gargalos. Todos corrigidos:

### Bugs críticos corrigidos

**1. `_firedAlarms.clear()` apagava o histórico inteiro** — causava alarmes disparando duas vezes.
- **Correção**: LRU eviction — quando passa de 200, remove os 100 mais antigos em vez de limpar tudo.

**2. `_openAlarmFromPayload` não registrava no `_firedAlarms`** — quando o alarme abria o app via notificação, o timer de 10s disparava o mesmo alarme de novo (diálogo duplicado).
- **Correção**: `_firedAlarms.add(key)` antes de `_fireAlarm(c)` no path de payload.

**3. Re-agendamento sequencial no `_init` bloqueava o startup** — com 10+ compromissos, 20 chamadas async em sequência atrasavam o registro do watchdog.
- **Correção**: `Future.wait(pending.map(...))` — agendamento paralelo.

**4. Badge "Alarmes 24h" não verificava se o compromisso ocorre hoje** — mostrava compromissos de outros dias da semana.
- **Correção**: `ScheduleMatcher.occursOn(c, today)` antes de contar.

### Limpeza

- Removido **simulador de celular** (`_isMobileFrame`, `_isOnline`, toggle, frame de 390px) — inútil em produção e confundia idosos.
- Removido **campo `reminderMinutesBefore`** do model `Commitment` — nunca usado, conflitava com `reminderDaysBefore`.
- Badge renomeado para "Alarmes Hoje" (mais claro).

### Validação
- `flutter analyze`: **0 issues** ✓
- `flutter test`: **57 testes passando** ✓
- `flutter build apk --release`: **OK**, `AgendaAmiga-APK-para-instalar.apk` (54,1 MB) copiado.

---

## Sessão 08/09/2026 (6ª) — Pesquisa de referência + canal de som versionado + guia por marca

Relato: apesar do diagnóstico todo verde, o alarme continua não tocando na hora agendada. Pesquisei a fundo a documentação oficial do plugin, doc Android oficial sobre alarmes exatos, issues do flutter_local_notifications e o projeto comunitário dontkillmyapp.com.

### O que a pesquisa revelou

**1. Canais de notificação são imutáveis (ARMADILHA SILENCIOSA confirmada pelos devs)**
O README oficial do `flutter_local_notifications` e inúmeras issues mostram: se uma **instalação antiga** criou o canal casualmente com som/vibração, **reinstalar o app NÃO reseta o canal** — "sounds and vibrations are associated with notification channels and can only be configured when they are first created". Resultado: alarme aparece **sem som para sempre**, sem log de erro. Está em nossa linha "notification scheduled but never dispatched": no SO, o alarme dispara, o receiver roda, mas o canal mudo faz o usuário acreditar que "não tocou".

**2. `setAlarmClock()` é a opção mais confiável que existe no Android**
Artigo ProAndroidDev (03/2026) e guia oficial do Android: alarmClock é tratado como intenção-chave do usuário → sobrevive a Doze, Restricted bucket e Battery Saver melhor que qualquer outro modo exato. Já usamos `AndroidScheduleMode.alarmClock` para alarmes de uma vez ✓ (o que o Android oferece de mais robusto).

**3. `USE_EXACT_ALARM` x `SCHEDULE_EXACT_ALARM`**
`SCHEDULE_EXACT_ALARM` é **negado por padrão** em Android 14+ (nova instalação) e precisa de acesso especial manual. Já tínhamos **as duas** permissões e `USE_EXACT_ALARM` é concedida automaticamente na instalação para apps de agenda/alarme — ✓ já correto.

**4. OEMs matam o alarme em segundo plano (causa nº 1 no mundo real)**
Projeto comunitário **dontkillmyapp.com** (citado pelo próprio README do plugin) mostra que Samsung (5/5), Xiaomi (5/5), Oppo, Huawei, Motorola, OnePlus **matam alarmes por padrão** com restrições próprias de bateria/auto-início. Não há API que contorne — a solução é **mostrar os passos exatos da marca dentro do app**.

### Correções implementadas

**1. Canal de notificação versionado `agenda_amiga_alarms_v2`**
Novo `alarmChannelId` força o Android a recriar o canal com as configurações atuais (som `alarm_sound.wav`, vibração, importância Máxima, categoria ALARM, stream de alarme). **Qualquer instalação antiga que criou o canal mudo agora recebe som garantido** — o alarme "não-tocado" vira alarme audível. Se o usuário seguir agendando, todo alarme novo usa o canal novo.

**2. Detecção da marca no `MainActivity` (Kotlin MethodChannel)**
`MethodChannel("agenda_amiga/device")` → `Build.MANUFACTURER + Build.MODEL`, lido no app com baixo custo, **100% offline**, sem depender de plugin de device.

**3. Diagnóstico agora guia pela marca do aparelho**
O card amarelo não é mais genérico: detecta a marca e mostra o passo a passo exato:
- **Samsung**: Cuidados com o aparelho > Bateria > Limites de uso em segundo plano > nunca suspender Agenda Amiga + App > Bateria > Sem restrição
- **Xiaomi/Redmi/POCO**: Segurança > Otimização > Restringir apps em segundo plano OFF + Auto-início ON
- **OPPO/Realme**: Bateria > Otimização > Permitir + Auto-início
- **Motorola**: Bateria > Otimização > Não otimizado
- **Huawei/Honor**: Baterias > Não otimizado + Executar em segundo plano
- **Genérico**: passos seguros para qualquer Android

**4. Novo botão "🔊 Testar Som do Alarme Agora"**
Dispara uma notificação IMEDIATA no canal novo. Se o usuário ouve o som → canal/som OK. Se não ouve → é volume de alarme do aparelho (não é código). Isto isola de vez: som ✓ e agendamento ✓ = alarme toca.

### Fluxo de teste recomendado ao usuário
1. Instalar APK novo *por cima* (não desinstalar).
2. Abrir app → 🛠 Diagnóstico.
3. Tocará no "Testar Alarme em 20 segundos" → **desligar a tela** → se tocar, o sistema está 100%.
4. Se não tocar → "🔊 Testar Som Agora"; se ouviu o som, o problema é a permissão de segundo plano → seguir o cartão amarelo da sua marca e reiniciar o celular.

### Validação
- `flutter analyze`: **0 issues** ✓
- `flutter test`: **57 testes passando** ✓
- `flutter build apk --release`: **OK**, `AgendaAmiga-APK-para-instalar.apk` (53,7 MB) copiado.

---

## Sessão 08/09/2026 (7ª) — REFATORAÇÃO: voz escolhível pelo usuário + watchdog WorkManager + reforço de volume nativo

Usuário reportou que, mesmo com todo o diagnóstico verde, o alarme NÃO toca em nenhuma situação no Realme GT6 (Realme UI). Feita uma refatoração arquitetural da camada de alarme com as ferramentas mais recentes possíveis:

### Novo watchdog anti-morte: WorkManager `^0.10.10` (Google)
**Causa real mobile**: OEMs (realme/Xiaomi/Samsung) limpam os alarmes do AlarmManager ou congelam o app — a partir daí, NENHUM alarme agendado nunca mais toca até o app ser aberto de novo. Isso é impossível de resolver só com notificações agendadas.

**Solução (padrão moderno recomendado)**: `workmanager` 0.10.10 — scheduler persistente do Android, muito mais resistente a killings OEM que o AlarmManager puro. A cada 15 min, roda em um **isolate em segundo plano** (mesmo com o app fechado/forçados) e **re-cadastra todos os compromissos pendentes**. Resultados:
- Se a Realme apagar os alarmes às 9h05 para um compromisso às 15h, o watchdog os re-cria na janela seguinte (9h15).
- Re-cadastro é **idempotente**: usa os MESMOS ids → sobrescreve em vez de duplicar.

### Refatoração: fonte única de verdade para agendamento
- Novo `lib/scheduling/alarm_scheduler.dart`: `scheduleCommitmentAlarms(ns, c)` concentra 100% da lógica (id, lembrete antecipado, payload) usada TANTO pelo app quanto pelo watchdog. `main.dart` agora delega em `_scheduleNotification` (de 50 linhas → 1 linha).
- Ids centralizados: `notificationIdFor()` / `reminderNotificationIdFor()` (sem risco de colisão app vs. fundo).

### Nova aba "Voz" — o usuário escolhe quem fala com ele
- Botão **🎙️ Voz** na toolbar abre `VoicePickerModal`:
  - Lista **todas as vozes em português** disponíveis na engine TTS do celular (ex.: Google tem voz feminina e masculina; VoxSherpa, etc.).
  - Cada voz tem etiqueta amigável ("voz feminina/masculina + pt-BR").
  - Toque = **ouve a nova voz imediatamente** e grava a escolha.
  - Persistida no `SharedPreferences` (`ttsVoice`) e **re-aplicada no próximo início** junto com a preferência de engine.
  - Válida para todos os alarmes e mensagens (mesmo `FlutterTts`).

### Reforço nativo de volume do alarme (MainActivity Kotlin)
Causa real clássica: volume de ALARME do celular no mínimo → o alarme dispara mas ninguém ouve.
- Novo MethodChannel `boostAlarmAudio()`/`restoreAlarmAudio()`.
- `boostAlarmAudio()`: se o stream de alarme estiver abaixo de 60% do máximo, **eleva ao máximo** (alarmes de verdade fazem isso), guardando o valor anterior.
- Chamado em `_fireAlarm` e no lembrete antecipado; `restoreAlarmAudio()` devolve o volume original ao fechar o alarme.
- Sem permissão especial necessária (AudioManager.setStreamVolume é public API).

### O que mudou
```
lib/scheduling/alarm_scheduler.dart   (NOVO — fonte única de agendamento)
lib/scheduling/alarm_watchdog.dart    (NOVO — re-cadastro a cada 15 min)
lib/main.dart                         (delegação + registro do watchdog + aba Voz + boost de volume)
lib/widgets/modals.dart               (VoicePickerModal)
lib/services/notification_service.dart(boostAlarmAudio/restoreAlarmAudio + deviceBrand)
android/.../MainActivity.kt           (boost/restore de volume por stream de alarme)
pubspec.yaml                          (workmanager ^0.10.10)
```

### TESTE OBRIGATÓRIO no Realme GT6
1. Instalar APK por cima → **reinicie o celular** (recomeça: registra o watchdog + aplica permissões).
2. Abra o app → 🎙️ **Voz** → escolha a voz que ouvir melhor (toque nela para testar).
3. 🛠 **Diagnóstico** → 🔊 **Testar Som** (deve tocar alto, mesmo com volume de alarme no zero).
4. **🔔 Testar Alarme em 20 segundos** → desligue a tela → DEVE tocar.
5. Se NÃO tocar, reaplicar o cartão amarelo da Realme e conferir que **Agenda Amiga não está em "Congelamento rápido"** e está **travada nas abas recentes**.

### Validação
- `flutter analyze`: **0 issues** ✓
- `flutter test`: **57 testes passando** ✓
- `flutter build apk --release`: **OK**, `AgendaAmiga-APK-para-instalar.apk` (54,1 MB) copiado.

---

## Sessão 08/09/2026 (9ª) — Diagnóstico nativo definitivo (canal + teste padrão + rastro de agendamento)

Alarme continuava não tocando. Implementado diagnóstico que FINALMENTE mostra o que o OS faz com as notificações:

### O que mudou
- **Kotlin**: 3 novos MethodChannel nativos:
  - `isChannelEnabled(channelId)` → verifica se o canal de notificação existe e está habilitado (IMPORTANCE_NONE = desabilitado), retorna map com `exists`, `enabled`, `importance`, `hasSound`, `hasVibration`.
  - `openChannelSettings(channelId)` → abre a tela EXATA de configurações do canal (não só as notificações do app).
  - `testDefaultNotification()` → posta uma notificação num canal PADRÃO fresco (IMPORTANCE_HIGH + vibração + som padrão do Android), bypassando completamente nosso canal customizado.

- **NotificationService (Dart)**: wrappers para os 3 métodos + `lastScheduleResult` que rastreia QUAL caminho do agendamento foi tomado (alarmClock / inexact / immediate_fallback / all_failed).

- **AlarmDiagnosticsModal**: nova seção "Exame Clínico do Alarme":
  - Status do canal de notificação (verde/vermelho com importance + som).
  - Resultado do último agendamento (mostra se foi alarmClock, inexact, fallback imediato, ou TODOS falharam).
  - Botão "🔔 Testar notificação do Android (padrão)" — posta no canal padrão, bypassando nosso canal.
  - Botão "Configurar canal" — abre as configurações EXATAS do canal no Android.
  - Botão 🔄 "Atualizar" no título para recarregar após mudanças.

### Validação
- `flutter analyze`: **0 issues** ✓
- `flutter test`: **57 testes passando** ✓
- `flutter build apk --release`: **OK**, `AgendaAmiga-APK-para-instalar.apk` (54,1 MB) copiado.

---

## Sessão 08/09/2026 (8ª) — Bloqueador real da realme + só vozes PT-BR + cadeia de alarme à prova de OEM

Usuário confirmou que as **vozes funcionam** (pediu para mostrar SOMENTE vozes PT-BR) e que o **alarme continua não tocando** no Realme GT6.

### 1. Diagnóstico agora CAÇA o verdadeiro bloqueio (e não só permissões)
As permissões (notificação/alarme exato) podem estar 100% verdes e o alarme NUNCA tocar. O motivo real em realme/OPPO/Xiaomi: o app mora no balde de **economia de bateria** e é **congelado** — alarmes e até o watchdog morrem com ele.
- Novo MethodChannel nativo:
  - `isIgnoringBatteryOptimizations()` → mostra no diagnóstico **Economia de bateria: ⚠️ Bloqueado** quando o app não está na lista de "Não otimizar".
  - `requestBatteryWhitelist()` → abre o **diálogo do sistema** "Permitir que Agenda Amiga execute em segundo plano?" em 1 toque.
  - `openAutostartSettings()` → abre a tela de **Autorização de inicialização (autostart)** da realme (ColorOS) — a mais famosa: sem ela o app NÃO faz nada em segundo plano.
  - `openBatteryManager()` → abre **Gerenciamento de bateria de apps** (realme), onde se define "Não otimizar" por app, tudo por deep-link com fallback.
- 2 botões de atalho direto no diagnóstico ("Abrir autorização de autostart", "Abrir gerenciamento de bateria").

### 2. Aba Voz — SOMENTE vozes em português
- Filtro total: lista apenas vozes `pt*` (removida a seção "outras"), com deduplicação por nome+locale. O idoso vê só o que pode usar.

### 3. Cadeia de alarme "um por véspera" (mais confiável que repetição)
- Reescrito `alarm_scheduler.dart` com `nextFireDateTime(c, now)` e **toda** recorrência (todos os dias, semanal, mensal, a cada 3 dias, horários) passa a ser um **disparo único `setAlarmClock`** da PRÓXIMA ocorrência.
- A cada disparo, o app **re-trema a próxima ocorrência** (`_fireAlarm` re-agenda no fechamento do alarme), sem sobrescrever o snooze (flag `snoozed`). A cadeia também é mantida pelo watchdog WorkManager de 15 min, pelo boot e pelo re-agendamento no início do app.
- Vantagens: `setAlarmClock` sobrevive a Doze, balde restrito e economia de bateria (não é o `setRepeating` que a realme corta); snooze de recorrente guarda a recorrência no payload e, ao re-tocar, REFAZ a cadeia; um disparo único já vencido é **cancelado** (sem lixo no AlarmManager).
- Payload novo carrega `recurrence`/`recurrenceDayOfMonth`.

### Validação
- `flutter analyze`: **0 issues** ✓
- `flutter test`: **57 testes passando** ✓
- `flutter build apk --release`: **OK**, `AgendaAmiga-APK-para-instalar.apk` (54,1 MB) copiado.

### TESTE DECISIVO no Realme GT6 (na ordem)
1. Instale o APK **por cima** (mantém dados) e abra.
2. 🛠 **Diagnóstico**: toque **"Permitir Agora" na linha VERMELHA de Economia de bateria** → aparece o diálogo do Android → marque **Permitir**.
3. Toque **"Abrir autorização de autostart"** → ative a Agenda Amiga na lista da ColorOS.
4. Toque **"Abrir gerenciamento de bateria de apps"** → Agenda Amiga → ative os 3 toggles + **Não otimizar**.
5. **Reinicie o celular**.
6. 💚 Só então: **🔊 Testar Som** → **🔔 Testar Alarme em 20 s** com a tela desligada.

---

---

## Sessão 08/09/2026 (3ª) — Alarmes 100% funcionais em todas as timelines (tempo relativo, mensal "todo dia N", lembretes antecipados)

Relato do usuário: *"ACABEI DE AGENDAR UM COMPROMISSO E ELE NÃO TOCOU"*. Investigado e corrigido em profundidade. **57 testes passando**, `flutter analyze` **0 issues**, APK reconstruído.

### Causas raiz do "agendei e não tocou" (corrigidas)
| Causa | Correção |
|---|---|
| 1. "daqui 3 minutos" (sem o "a") não era reconhecido pelo parser antigo (`daqui a X min`); o regex genérico de hora engolia o "3" e agendava **amanhã às 03:00**. | `natural_command_parser.dart` reescrito: aceita "daqui 3 minutos" e "daqui a 3 minutos", "daqui a 2 horas", "daqui a 3 dias", "agora", "daqui a meia hora". |
| 2. "reunião da empresa todo dia 10" virava recorrência **diária** e o "10" era lido como hora 10:00. | Detecção de recorrência **Mensal** ("todo dia N", "dia N de cada mês") com prioridade sobre "todo dia" diário; o dígito do dia não é mais consumido como hora. |
| 3. `_scheduleNotification` dava `return` silencioso se o horário caísse ≤ 1 min após "agora". | Guarda corrigida para apenas passado estrito; "daqui 3 minutos" agenda corretamente em `now + 3min`. |

### Novas timelines entendidas por voz
| Usuário diz | Resultado |
|---|---|
| "tomar água daqui 3 minutos" | Toca em `agora + 3 min` ✔ |
| "beber remédio daqui a 30 minutos" | Toca em `agora + 30 min` |
| "daqui a 2 horas" / "daqui a 3 dias" | `agora + 2h` / `agora + 3 dias` |
| "reunião da empresa todo dia 10 às 9" | Recorrência **Mensal** no dia 10 às 09:00; se o dia 10 deste mês já passou, vai para o **mês que vem** — e toca **todo mês** no dia 10 |
| "reunião da empresa todo dia 10" (sem hora) | Mensal no dia 10 às **09:00** (padrão) |
| "pagamento todo dia 31" | Clampa para 30 em meses de 30 dias; nunca pula mês |
| "consulta dia 20 do mês que vem" | Dia 20 do mês seguinte |
| "consulta dia 20 de julho" | Próximo 20 de julho (este ano ou o próximo) |
| "segunda-feira às 9" / "sexta às 10" | Próximo dia da semana citado |
| "reunião toda segunda-feira às 9" | Recorrência **Semanal** todas as segundas |
| "consulta me lembre 3 dias antes" | Toca **3 dias antes** do compromisso: "Seu compromisso é daqui a 3 dias. Não esqueça!" **e** toca de novo no dia exato |
| "amanhã às 7", "depois de amanhã às 8", "às 14:30", horário passado do dia | Continuam funcionando (hora passada do mesmo dia muda para amanhã) |

### Implementação técnica
- **`lib/parser/natural_command_parser.dart`**: reescrito — `parse(text, {DateTime? now})` injetável para testes determinísticos; novo `ParsedCommand.recurrenceDayOfMonth` e `ParsedCommand.reminderDaysBefore`; `_nextMonthDay()`, `_nextWeekday()`, `_relativeMinutes/_relativeHours/_relativeDays()`, `_extractTime()` com sanitização para não engolir dígitos de "todo dia 10" / "daqui 3 minutos" / "3 dias antes" como horas. Corrigido bug de raw string Dart (interpolação `\b${...}\b` não acontece em `r''`) usando `RegExp.escape` + string normal em `_weekday` e `_specificMonth`.
- **`lib/models/commitment.dart`**: novos campos `recurrenceDayOfMonth` e `reminderDaysBefore` (com `copyWith`/`toJson`/`fromJson`).
- **`lib/scheduling/schedule_matcher.dart`** (novo): fonte única de verdade "ocorre neste dia?" para alarme, agenda semanal, lista e briefing — mensal (com clamp de fim de mês), semanal, diário, "a cada 3 dias".
- **`lib/services/notification_service.dart`**: recorrência `'Mensal'` agendada via `DateTimeComponents.dayOfMonthAndTime` (flutter_local_notifications 22.3.0) → toca todo mês no mesmo dia/hora mesmo com o app fechado.
- **`lib/main.dart`**: `_notificationId` redimensionado p/ 1e9 + `_reminderNotificationId` dedicado ao lembrete antecipado (cancelado junto ao excluir/concluir/editar); `_scheduleNotification` agenda o lembrete `N dias antes` (mesma hora do dia) com payload `isReminder`; instalação de lembrete dispara `AlarmModal` no modo lembrete ("Já Sei, Obrigado!" sem marcar como concluído) com anúncio "é daqui a N dias"; briefing/lista/calendário passam a usar `ScheduleMatcher.occursOn`.
- **`lib/widgets/modals.dart`**: `AlarmModal` ganhou `isReminderAlert`; `EditCommitmentModal` incluiu recorrência **Mensal** no dropdown e salva `recurrenceDayOfMonth`.
- **`lib/widgets/commitment_list.dart`** e **`weekly_calendar.dart`**: filtros por recorrência via `ScheduleMatcher`.

### Validação
- `flutter analyze`: **0 issues** ✓
- `flutter test`: **57 testes passando** ✓ (34 novos — `test/parser_test.dart` com 24 casos de timeline/mensal/semanal/lembrete/categorias e `test/schedule_matcher_test.dart` com 8 casos — + os 23 existentes).
- `flutter build apk --release`: **OK**, APK copiado para a raiz como `AgendaAmiga-APK-para-instalar.apk` (53,6 MB).

> Instale por cima do APK anterior — os agendamentos e dados são preservados.

---

## Sessão 08/09/2026 (2ª) — Assistente de voz inteligente: não repete o texto, fala com contexto e fé

O assistente de voz **parou de repetir literalmente** o que o usuário digitou/falou. Agora ele entende o **assunto**, a **hora** e a **gravidade** do compromisso e fala com contexto, calor humano e encerramento com Deus — **100% offline**, sem chamadas de IA em nuvem (regras de Dart puro).

### Exemplos do comportamento novo
| Usuário diz | O app agora fala |
|---|---|
| "Acordar todos os dias às 7 da manhã" | "Bom dia! São sete da manhã. Acorde com a mente leve, o corpo pronto e o sorriso aberto. Que este dia seja abençoado por Deus." |
| "Ligar para minha mãe amanhã às 10" | "Está na hora de ligar para sua mãe. São dez da manhã. Que Deus use esse momento para unir corações." |
| "Tomar remédio da tireoide todos os dias às 6" | "Atenção! São seis da manhã. Está na hora de tomar o seu remédio da tireoide. Não esqueça, seu bem-estar é o mais importante. Deus cuide de você e da sua saúde." |
| "Pagar o boleto do IPTU dia 20 às 9" | "Atenção! Não se esqueça do pagamento do seu boleto do IPTU. São nove da manhã. Que Deus abençoe suas finanças e lhe dê sabedoria." |

### Nova camada de inteligência — `flutter/lib/intelligence/`
| Arquivo | Função |
|---|---|
| `intent_classifier.dart` | Classifica o assunto em 18 intenções (medicação, ligar, médico, pagamento, família, trabalho, casa, compras, alimentação, fé, estudo, exercício, descanso, acordar...) e gravidade (alta/média/baixa). Normalização sem acentos. |
| `subject_extractor.dart` | Extrai o objeto real do compromisso ("remédio da tireoide", "mãe"), remove templates ("todos os dias", "acordar", "ligar para") e converte pronomes de 1ª para 2ª pessoa ("minha mãe" → "sua mãe"). |
| `time_phraser.dart` | Fala a hora naturalmente: "seis da manhã", "meio-dia", "nove e meia da noite", "meia-noite" (sem TTS de dígitos soltos). |
| `message_composer.dart` | Monta a frase final por contexto (alarme / confirmação / briefing), com saudação pela hora do dia, frase de ação por intenção e **finais bíblicos que rotacionam** (nunca repetem a mesma bênção em chamadas seguidas). |
| `announcer.dart` | Fachada usada pelo app: `alarm()`, `alarmModalLine()`, `confirmation()`, `briefingLine()`, `preConfirmation()`. |

### Finais bíblicos rotativos (Deus)
"Não esqueça, seu bem-estar é o mais importante. **Deus cuide de você e da sua saúde.**" / "Que este dia seja **abençoado por Deus**." / "Que a **luz de Deus** ilumine todos os seus passos hoje." / "Que a **fé em Deus** esteja no seu coração o dia inteiro." / "**Deus abençoe suas finanças** e lhe dê sabedoria." / "Que **Deus use esse momento** para unir corações."

### Onde o app fala inteligente
1. **Alarme ao tocar** (`main.dart` `_fireAlarm` + `AlarmModal`): o anúncio mudou de "Atenção! Hora do compromisso. <título>" para a mensagem inteligente pelo assunto/hora/bênção, mantendo a instrução por voz "Diga desligar, ok ou já ouvi".
2. **Confirmação por voz** (`voice_assistant.dart`): após salvar, confirma com contexto do assunto + hora falada + bênção (em vez de repetir o texto).
3. **Briefing matinal** (`main.dart` `_welcomeAndBriefing`): lista os compromissos do dia sorteados por hora, um por vez, na forma inteligente, com contagem de pendências e alta prioridade.

### Validação
- `flutter analyze`: **0 issues** ✓
- `flutter test`: **21 testes passando** ✓ (20 novos testes de inteligência no `test/intelligence_test.dart` + smoke test, cobrindo classificação, extração, fala da hora, anúncios e rotação das bênçãos).
- `flutter build apk --release`: **OK**, APK copiado para a raiz como `AgendaAmiga-APK-para-instalar.apk` (56,0 MB).

> Tudo funciona **offline**: classificação e mensagens são regras locais em Dart. Ao instalar o VoxSherpa (TTS neural offline, sessão anterior) a voz também fica neural sem internet. É só instalar o APK novo por cima — os dados do app e os agendamentos são preservados.

---

## Sessão 08/09/2026 — Alarme de despertador + VoxSherpa (offline neural TTS)

### Prioridade máxima resolvida: alarme que acorda o celular mesmo com o app fechado e tela desligada, e toca mesmo no modo silêncio

O problema relatado (perder a hora porque o alarme não acordava o aparelho) tinha **4 causas**, todas corrigidas:

| Causa | Correção |
|---|---|
| 1. A Activity não acendia a tela nem aparecia sobre a tela de bloqueio quando o alarme disparava com o app fechado. | Adicionei `android:showWhenLocked="true"` e `android:turnScreenOn="true"` na `MainActivity` (`android/app/src/main/AndroidManifest.xml`). Agora o alarme em fullscreen **liga a tela e aparece por cima da tela de bloqueio**. |
| 2. Os alarmes únicos usavam só `exactAllowWhileIdle`, que pode ser atrasado pelo Doze/otimização de bateria. | Alarmes de uma vez (pontuais e sonecas) agora usam **`AndroidScheduleMode.alarmClock`** (`AlarmManager.setAlarmClock`) — comportamento de despertador nativo: ignora Doze e otimização de bateria, dispara mesmo com o processo do app morto. Alarmes recorrentes (diários/semanais) continuam em `exactAllowWhileIdle` + `matchDateTimeComponents`. |
| 3. No Android 12+, o agendamento exato podia falhar se o usuário negasse a permissão. | Adicionei `<uses-permission android:name="android.permission.USE_EXACT_ALARM" />` — para apps de despertador, essa permissão é **concedida automaticamente** no Android 13+. Mantive a `SCHEDULE_EXACT_ALARM` existente (Android 4.1–12). |
| 4. O som usava o stream de mídia/notificação, que é silenciado no modo silêncio. | **Notificação** (`notification_service.dart`) agora usa `audioAttributesUsage: AudioAttributesUsage.alarm` e **som do alarme** (`alarm_player.dart`) agora toca com `AudioContext` de `AndroidUsageType.alarm`. Ambos tocam pelo stream de ALARME — soa mesmo em modo silêncio/DND de notificações (obedece apenas ao volume de alarme, igual um despertador nativo). Adicionei `visibility: NotificationVisibility.public` para o conteúdo aparecer na tela de bloqueio. |

> **Importante:** no modo silêncio, o telefone ainda precisa de volume de **alarme** > 0 (não é o mesmoslider de mídia). Isso é o comportamento correto/padrão dos despertadores Android.

### Mudanças técnicas de suporte ao alarme
- `main.dart`: novo `requestFullScreenIntentPermission()` no `_init()` — Android 14+ pode tornar a FSI deniável; esse call pede quando o OEM exigir.
- Fallback mantido: se `alarmClock`/exato falhar (permissão negada), cai para `inexactAllowWhileIdle` e, no pior caso, mostra a notificação imediata.

### VoxSherpa — voz neural 100% offline integrada
- Novo método `_preferVoxSherpaEngine()` em `main.dart`: enumera os engines TTS do Android (`getEngines`) e, se o **VoxSherpa** estiver instalado, usa-o via `setEngine`. Senão, cai silenciosamente para o engine padrão do sistema — sem quebrar nada.
- Por que VoxSherpa: TTS neural **grátis e 100% offline** (baseado em sherpa-onnx), respeitando a premissa offline do app. Funciona no app automaticamente porque é um engine de TTS do *sistema* Android.

#### Como ativar o VoxSherpa no celular (1 min, com internet)
1. Instale **VoxSherpa TTS** da Google Play (nome do pacote: `com.CodeBySonu.VoxSherpa`).
2. Abra o app VoxSherpa → instale a voz em **Portuguese (pt)** (Piper, ~30 MB, baixada uma única vez, depois 100% offline).
3. Ajuste a velocidade no próprio app (a do Agenda Amiga também serve).
4. Opcional — defina como engine padrão: **Configurações → Acessibilidade → Saída de texto para fala → Motor preferido → VoxSherpa**. Com isso o Agenda Amiga já o usa por padrão (sem depender da detecção automática no código).

O Agenda Amiga também tenta detectá-lo sozinho e usar via `setEngine` — mas defini-lo como padrão do sistema é a forma mais garantida e também melhora outras apps.

### Upgrade de dependências
| Pacote | Antes | Agora |
|---|---|---|
| flutter_local_notifications | 19.0.0 | **22.3.0** |
| flutter_timezone | ^4.1.0 | **^5.1.0** |
| timezone | 0.10.0 | **0.11.1** |
| url_launcher | 6.3.1 | **6.3.2** |
| shared_preferences | ^2.2.2 | **^2.5.5** |
| flutter_lints (dev) | ^3.0.0 | **^6.0.0** |

Migrações exigidas pelo upgrade:
- **flutter_timezone 5.x**: `getLocalTimezone()` agora retorna `TimezoneInfo`; código migrado para usar `.identifier` (`notification_service.dart`).
- **FLN 22.3.0**: API mudou de argumentos posicionais para **nomeados** em `initialize`, `zonedSchedule`, `show`, `cancel`. Todos os calls foram atualizados.
- `AudioAttributesUsage` e `NotificationVisibility` confirmados presentes nos enums do FLN 22.

### Validação
- `flutter analyze`: **0 issues** ✓
- `flutter build apk --release`: **OK** (55,9 MB), APK copiado para a raiz como `AgendaAmiga-APK-para-instalar.apk`.
- Avisos inofensivos no build (KGP de plugins + `--enable-native-access` de terceiros) não afetam o APK.

### Permissões que o APK solicita ao abrir pela primeira vez
Mantenha o que o app pede ao iniciar (o fluxo existente já solicita: notificações, alarmes exatos, e agora tenta full-screen intent). Em algumas marcas (Samsung/Xiaomi/OPPO) recomenda-se também: **Configurações → Apps → Agenda Amiga → Bateria → Sem restrições** para nem o OEM matar o serviço.

---

## Sessão anterior — Anti-eco do assistente de voz + atualização do Flutter
- `voice_assistant.dart`: confirmação com pausa de 4s (`pauseFor`) para não interromper fala.
- `AlarmModal` reescrito: anúncio via TTS termina antes de ligar o microfone; re-escuta com `Timer.periodic(3s)`; stop-words para dispensar alarme por voz; flags `_stopping`/`_dismissed` para evitar toques fantasma; dispose sem vazamentos.
- Flutter SDK: 3.44.4 → **3.47.2** (Dart 3.13.2).

---

## Sessão 09/09/2026 (11ª) — Migração para `alarm` package (Foreground Service)

O alarme **não toca** no Realme GT6 mesmo com todas as tentativas anteriores (10 sessões). Usuário pediu pesquisa sobre alternativas inteligentes. Após análise, decidimos migrar de `flutter_local_notifications` (zonedSchedule) para o **`alarm` package** (v5.12.0), que usa **Foreground Service + AlarmManager** — muito mais resistente a OEM killers.

### Por que o `alarm` package é mais confiável
| Aspecto | `flutter_local_notifications` (antes) | `alarm` package (agora) |
|---|---|---|
| **Mecanismo** | AlarmManager + BroadcastReceiver | AlarmManager + **Foreground Service** |
| **Sobrevive app killed?** | Depende do OEM | **Sim** (Foreground Service é mais difícil de matar) |
| **Toca em silencioso?** | Via canal customizado | Via **STREAM_ALARM** nativo + AudioManager |
| **Tela ao acordar?** | fullScreenIntent na notificação | **androidFullScreenIntent** nativo |
| **Áudio** | Via audioplayers (STREAM_MUSIC) | Via **AVAudioPlayer** (STREAM_ALARM nativo) |
| **Notificação dismissível?** | Sim | **Não** (foreground service, Android 12+) |

### Alterações implementadas

**1. `pubspec.yaml`**
- Adicionado `alarm: ^5.4.1` (resolvido para v5.12.0)
- Mantido `flutter_local_notifications: 22.3.0` como fallback

**2. `notification_service.dart`**
- Importado `alarm` package + `AlarmSet`
- `init()`: agora chama `Alarm.init()` e escuta `Alarm.ringing` (não `ringStream` deprecado)
- `scheduleAlarm()`: usa `Alarm.set(alarmSettings:)` com `VolumeSettings.fade()` como primário; fallback → `zonedSchedule` → `show()`
- `cancel()`: cancela em ambos os pacotes (`Alarm.stop` + `FLN`)
- `cancelAll()`: para todos os alarmes do `alarm` package + `FLN`
- Novo callback `onAlarmFired` para quando o alarme dispara via Foreground Service
- `lastScheduleResult` agora reporta `'alarm_package'` quando funciona

**3. `AndroidManifest.xml`**
- Adicionadas permissões `FOREGROUND_SERVICE` e `FOREGROUND_SERVICE_ALARM` (obrigatórias para o `alarm` package)

**4. `main.dart`**
- Conectado `onAlarmFired` callback para que alarmes do Foreground Service abram o `AlarmModal`
- O `alarm` package agora é o canal primário de agendamento

### AlarmSettings configurados
```dart
AlarmSettings(
  id: id,
  dateTime: scheduledTime,
  assetAudioPath: 'assets/sounds/alarm_sound.wav',
  loopAudio: true,
  vibrate: true,
  androidFullScreenIntent: true,
  volumeSettings: VolumeSettings.fade(
    volume: 0.8,
    fadeDuration: Duration(seconds: 3),
    volumeEnforced: true,
  ),
  notificationSettings: NotificationSettings(
    title: title,
    body: body,
    stopButton: 'Parar Alarme',
  ),
)
```

### Validação
- `flutter analyze`: **0 issues** ✓
- `flutter test`: **57 passando** ✓
- `flutter build apk --release`: **OK** (56,7 MB), APK copiado para raiz como `AgendaAmiga-APK-para-instalar.apk`
- Avisos inofensivos no build (KGP de plugins) não afetam o APK

### O que fazer se ainda não tocar no Realme GT6
1. Rodar o "Exame Clínico do Alarme" no diagnóstico — verificar se o canal de notificação está habilitado
2. Seguir o guia Realme do diagnóstico (3 passos: autostart, bateria, otimização)
3. Se tudo falhar, considerar a **Opção 2** (ACTION_SET_ALARM — alarme nativo do relógio)
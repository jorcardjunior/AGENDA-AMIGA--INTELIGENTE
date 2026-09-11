import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/commitment.dart';
import 'intelligence/announcer.dart';
import 'parser/natural_command_parser.dart';
import 'scheduling/alarm_scheduler.dart';
import 'scheduling/alarm_watchdog.dart';
import 'scheduling/schedule_matcher.dart';
import 'services/notification_service.dart';
import 'services/permission_guard.dart';
import 'utils/date_formatter.dart';
import 'widgets/commitment_list.dart';
import 'widgets/modals.dart';
import 'widgets/monthly_calendar.dart';
import 'widgets/voice_assistant.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AgendaAmigaApp());
}

class AgendaAmigaApp extends StatelessWidget {
  const AgendaAmigaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda Amiga',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D9488)),
        useMaterial3: true,
        fontFamily: 'sans-serif',
        scaffoldBackgroundColor: const Color(0xFFF4FDFB),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts _tts = FlutterTts();
  final NotificationService _notifications = NotificationService();

  final List<Commitment> _commitments = [];
  int _nextId = 1;
  String _selectedDate = DateFormatter.todayStr();
  Timer? _alarmTimer;
  final Set<String> _firedAlarms = {};
  String? _lastBriefingDate;
  bool _isSpeaking = false;
  int _alarmCount24h = 0;
  String? _savedVoice;

  // Trava de Segurança da Agenda
  bool _isAgendaLocked = false;
  String? _agendaPin;
  String? _recoveryEmail;
  String? _recoveryPhone;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('commitments');
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      _commitments.addAll(list.map((e) => Commitment.fromJson(e as Map<String, dynamic>)));
    }
    _nextId = prefs.getInt('nextId') ?? (_commitments.isEmpty ? 1 : _commitments.length + 1);
    _lastBriefingDate = prefs.getString('lastBriefingDate');
    _savedVoice = prefs.getString('ttsVoice');
    _isAgendaLocked = prefs.getBool('isAgendaLocked') ?? false;
    _agendaPin = prefs.getString('agendaPin');
    _recoveryEmail = prefs.getString('agendaRecoveryEmail');
    _recoveryPhone = prefs.getString('agendaRecoveryPhone');

    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      // Prefer VoxSherpa (offline neural TTS, respects the app's 100% offline
      // promise) whenever it is installed & enabled as an Android TTS engine.
      // Falls back silently to the system default engine otherwise.
      await _preferVoxSherpaEngine();
      // Apply the voice the user picked in the Voz tab (persisted).
      final saved = _savedVoice;
      if (saved != null && saved.isNotEmpty) {
        try {
          await _applyVoice(saved);
        } catch (_) {}
      }
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
    } catch (_) {}

    await _notifications.init();
    _notifications.onNotificationTap = (id, payload) {
      if (payload.isEmpty) return;
      _openAlarmFromPayload(payload);
    };
    // Listen to alarm ring events from the `alarm` package (Foreground Service).
    _notifications.onAlarmFired = (alarmId, payload) {
      if (payload.isEmpty) return;
      _openAlarmFromPayload(payload);
    };

    // Pede TODAS as permissões críticas de uma vez (notificações, alarme exato,
    // otimização de bateria, full screen intent). O PermissionGuard centraliza
    // e evita chamar permissões duplicadas.
    await PermissionGuard.requestAll();

    // Self-healing: re-arm all non-completed alarms on every cold start.
    // If the OS cleared them (e.g. after a force-stop that was later opened
    // again, or after an APK update), this brings them back without the user
    // having to re-create every commitment. Runs in parallel so the watchdog
    // registration below is not delayed by a long commitment list.
    final pending = _commitments.where((c) => !c.completed).toList();
    await Future.wait(pending.map((c) => _scheduleNotification(c)));

    // Background watchdog: re-arms alarms every 15 minutes via WorkManager so
    // OEM battery killers (realme, Xiaomi, Samsung...) cannot permanently
    // delete our scheduled alarms.
    await AlarmWatchdog.register();

    _alarmTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkAlarms());
    _welcomeAndBriefing();
  }

  // ---------------------------------------------------------------------------
  // TTS helpers — anti-echo: TTS blocks mic, mic stops TTS
  // ---------------------------------------------------------------------------
  Future<void> _preferVoxSherpaEngine() async {
    try {
      final engines = await _tts.getEngines;
      if (engines == null || engines.isEmpty) return;
      String? sherpa;
      for (final e in engines) {
        final name = e?.toString().toLowerCase() ?? '';
        if (name.contains('sherpa') || name.contains('vox')) {
          sherpa = e?.toString();
          break;
        }
      }
      if (sherpa != null) {
        await _tts.setEngine(sherpa);
        // Re-apply language after switching the engine.
        await _tts.setLanguage('pt-BR');
      }
    } catch (_) {}
  }

  /// Applies a voice saved as JSON `{"name": "...", "locale": "pt-BR"}`.
  Future<void> _applyVoice(String stored) async {
    try {
      final map = jsonDecode(stored) as Map<String, dynamic>;
      final name = map['name']?.toString() ?? '';
      final locale = map['locale']?.toString() ?? 'pt-BR';
      if (name.isNotEmpty) {
        await _tts.setVoice({'name': name, 'locale': locale});
      }
    } catch (_) {}
  }

  void _openVoicePickerModal() {
    showDialog(
      context: context,
      builder: (_) => VoicePickerModal(
        tts: _tts,
        currentVoice: _savedVoice,
        speakText: _speak,
        onSelected: (stored, voiceMap) async {
          _savedVoice = stored;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('ttsVoice', stored);
          await _applyVoice(stored);
          final label = voiceMap['name']?.toString() ?? '';
          _speak(label.isEmpty
              ? 'Voz escolhida com sucesso. Vou falar assim com você de agora em diante.'
              : 'Voz escolhida com sucesso. A partir de agora eu falo assim.');
        },
      ),
    );
  }

  Future<void> _speak(String text) async {
    try {
      if (_isSpeaking) {
        await _tts.stop();
        await Future.delayed(const Duration(milliseconds: 150));
      }
      if (mounted) setState(() => _isSpeaking = true);
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _stopSpeech() async {
    try {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } catch (_) {}
  }

  void _welcomeAndBriefing() {
    _speak('Agenda Amiga ativa e cuidando de você. Seja bem-vindo!');
    final today = DateFormatter.todayStr();
    if (_lastBriefingDate == today) return;
    _lastBriefingDate = today;
    SharedPreferences.getInstance().then((prefs) => prefs.setString('lastBriefingDate', today));

    final todayItems = _commitments
        .where((c) => !c.completed && ScheduleMatcher.occursOn(c, today))
        .toList();
    final todayCount = todayItems.length;
    final highCount = todayItems.where((c) => c.priority == 'Alta').length;
    final msg = todayCount == 0
        ? 'Bom dia! Você não possui compromissos pendentes para hoje. Aproveite o seu dia com a bênção de Deus!'
        : 'Bom dia! Você tem $todayCount compromissos pendentes hoje, sendo $highCount de alta prioridade. ${_briefingList(todayItems)}';
    Future.delayed(const Duration(seconds: 2), () => _speak(msg));
  }

  /// Builds a compact, intelligent list of today's commitments, one per line.
  String _briefingList(Iterable<Commitment> items) {
    final sorted = items.toList()..sort((a, b) => a.time.compareTo(b.time));
    final lines = sorted.take(6).map((c) => Announcer.briefingLine(c)).toList();
    if (sorted.length > 6) {
      lines.add('E mais ${sorted.length - 6} compromisso${sorted.length - 6 > 1 ? 's' : ''} ao longo do dia.');
    }
    return lines.isEmpty ? '' : lines.join(' ');
  }

  // ---------------------------------------------------------------------------
  // Storage
  // ---------------------------------------------------------------------------
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'commitments', jsonEncode(_commitments.map((c) => c.toJson()).toList()));
    await prefs.setInt('nextId', _nextId);
  }

  int _notificationId(Commitment c) => notificationIdFor(c.id);

  /// ID of the advance reminder ("me lembre N dias antes") notification.
  int _reminderNotificationId(Commitment c) => reminderNotificationIdFor(c.id);

  // ---------------------------------------------------------------------------
  // Alarm check loop (every 10s, matching web behavior)
  // ---------------------------------------------------------------------------
  bool _matchesSchedule(Commitment c, DateTime now, String nowHHMM) {
    if (c.time != nowHHMM) {
      // Loopings horários (De hora em hora, etc.) podem disparar em outros horários
      if (c.recurrence != 'De hora em hora' &&
          c.recurrence != 'A cada 2 horas' &&
          c.recurrence != 'A cada 3 horas') {
        return false;
      }
    }

    final today = DateFormatter.todayStr();
    if (!ScheduleMatcher.occursOn(c, today)) return false;

    if (c.recurrence == 'De hora em hora' ||
        c.recurrence == 'A cada 2 horas' ||
        c.recurrence == 'A cada 3 horas') {
      final startDate = DateFormatter.parseDate(c.date);
      final parts = c.time.split(':');
      final startHour = int.parse(parts[0]);
      final startMinute = int.parse(parts[1]);
      final start = DateTime(startDate.year, startDate.month, startDate.day, startHour, startMinute);
      if (now.isBefore(start)) return false;
      final interval = c.recurrence == 'De hora em hora'
          ? 60
          : c.recurrence == 'A cada 2 horas'
              ? 120
              : 180;
      final minsOnLoop = now.difference(start).inMinutes;
      return minsOnLoop >= 0 && minsOnLoop % interval == 0;
    }

    return true;
  }

  void _checkAlarms() {
    if (!mounted || _commitments.isEmpty) return;
    final now = DateTime.now();
    final nowHHMM =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Count alarms for the rest of today
    final today = DateFormatter.todayStr();
    int count = 0;
    for (final c in _commitments) {
      if (c.completed) continue;
      if (!ScheduleMatcher.occursOn(c, today)) continue;
      final parts = c.time.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final alarmTime = DateTime(now.year, now.month, now.day, h, m);
      if (alarmTime.isAfter(now)) count++;
    }
    if (mounted) setState(() => _alarmCount24h = count);

    for (final c in _commitments) {
      if (c.completed) continue;
      if (!_matchesSchedule(c, now, nowHHMM)) continue;
      final key = '${c.id}:${c.date}:${c.time}';
      if (_firedAlarms.contains(key)) continue;
      _firedAlarms.add(key);
      if (_firedAlarms.length > 200) {
        final oldest = _firedAlarms.toList();
        _firedAlarms.clear();
        _firedAlarms.addAll(oldest.sublist(oldest.length - 100));
      }
      _fireAlarm(c);
    }
  }

  void _fireAlarm(Commitment c) {
    _speak(Announcer.alarm(c));
    if (!mounted) return;
    // O volume do alarme é controlado nativamente pelo alarm package via
    // VolumeSettings.fade(volumeEnforced: true). Não é mais necessário
    // boostAlarmAudio/restoreAlarmAudio (causava conflito de AudioFocus).
    var snoozed = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlarmModal(
        title: c.title,
        time: c.time,
        commitmentId: c.id,
        speakText: _speak,
        stopSpeech: _stopSpeech,
        announcement: Announcer.alarm(c),
        onConfirmDone: () => _toggleComplete(c.id),
        onSnooze: () {
          snoozed = true;
          _snooze(c);
        },
      ),
    ).then((_) {
      // Re-arm the next occurrence for recurring commitments. Every OS alarm is
      // a one-shot; each firing extends the chain — unless the user marked it
      // done or is already snoozing this one.
      final active = _commitments.where((x) => x.id == c.id).firstOrNull;
      if (snoozed) return;
      if (active != null && !active.completed) {
        _scheduleNotification(active);
      }
    });
  }

  void _openAlarmFromPayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final id = data['id']?.toString() ?? '';
      final isReminder = data['isReminder'] == true;
      if (!mounted || id.isEmpty) return;
      final c = _commitments.where((x) => x.id == id).firstOrNull;
      if (isReminder) {
        final days = data['daysBefore']?.toString() ?? '';
        final announcement =
            'Atenção! Você tem um compromisso importante pela frente: ${data['title']} '
            'é daqui a $days dias. Não deixe para a última hora.';
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlarmModal(
            title: 'Lembrete: ${data['title']}',
            time: data['time']?.toString() ?? '',
            commitmentId: id,
            speakText: _speak,
            stopSpeech: _stopSpeech,
            announcement: announcement,
            isReminderAlert: true,
            onConfirmDone: () {},
            onSnooze: () => _snoozeReminder(data),
          ),
        );
        return;
      }
      if (c != null) {
        _firedAlarms.add('${c.id}:${c.date}:${c.time}');
        _fireAlarm(c);
      }
    } catch (_) {}
  }

  Future<void> _snoozeReminder(Map<String, dynamic> data) async {
    final when = DateTime.now().add(const Duration(minutes: 10));
    await _notifications.scheduleAlarm(
      id: _reminderNotificationIdFor(data['id']?.toString() ?? ''),
      title: data['title']?.toString() ?? '',
      body: 'Lembrete adiado: ${data['title']} continua por perto.',
      scheduledTime: when,
      recurrence: null,
      payload: jsonEncode({...data, 'isReminder': true}),
    );
  }

  int _reminderNotificationIdFor(String id) => reminderNotificationIdFor(id);

  Future<void> _snooze(Commitment c) async {
    final when = DateTime.now().add(const Duration(minutes: 10));
    await _notifications.scheduleAlarm(
      id: _notificationId(c),
      title: c.title,
      body: '🔔 Adiado. Lembrando: ${c.title} (movido para agora).',
      scheduledTime: when,
      recurrence: null,
      payload: jsonEncode({
        'id': c.id,
        'title': c.title,
        'time': c.time,
        'recurrence': c.recurrence,
        'recurrenceDayOfMonth': c.recurrenceDayOfMonth,
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Commitment operations
  // ---------------------------------------------------------------------------
  Future<void> _scheduleNotification(Commitment c) =>
      scheduleCommitmentAlarms(_notifications, c);

  Future<void> _addCommitment(ParsedCommand cmd) async {
    final c = Commitment(
      id: '${_nextId++}',
      title: cmd.title,
      date: cmd.date,
      time: cmd.time,
      priority: cmd.priority,
      category: cmd.category,
      completed: false,
      recurrence: cmd.recurrence == 'Único' ? null : cmd.recurrence,
      reminderDaysBefore: cmd.reminderDaysBefore,
      recurrenceDayOfMonth: cmd.recurrenceDayOfMonth,
      recurrenceDaysOfWeek: cmd.recurrenceDaysOfWeek,
      recurrenceEndDate: cmd.recurrenceEndDate,
      correctionNote:
          cmd.title.toLowerCase().contains('remedio') || cmd.title.toLowerCase().contains('remédio')
              ? 'Evite atrasos no seu tratamento!'
              : null,
    );
    setState(() => _commitments.add(c));
    await _persist();
    await _scheduleNotification(c);
  }

  Future<void> _toggleComplete(String id) async {
    final idx = _commitments.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final item = _commitments[idx];
    final updated = item.copyWith(completed: !item.completed);
    setState(() => _commitments[idx] = updated);
    await _persist();
    if (updated.completed) {
      _speak('Água que a sua ${item.recurrence == 'Todos os dias' ? 'tarefa diária' : 'tarefa'} '
          'concluída! Sua planta regada e seu jardim florindo mais uma vez. Parabéns!');
      await _notifications.cancel(_notificationId(item));
      await _notifications.cancel(_reminderNotificationId(item));
    } else {
      await _scheduleNotification(item);
    }
  }

  Future<void> _deleteCommitment(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir compromisso?'),
        content: const Text('Tem certeza que deseja excluir este lembrete?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final idx = _commitments.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final removed = _commitments[idx];
    setState(() => _commitments.removeAt(idx));
    await _persist();
    await _notifications.cancel(_notificationId(removed));
    await _notifications.cancel(_reminderNotificationId(removed));
    _speak('Compromisso ${removed.title} excluído com sucesso.');
  }

  Future<void> _editCommitment(Commitment updated) async {
    final idx = _commitments.indexWhere((c) => c.id == updated.id);
    if (idx == -1) return;
    setState(() => _commitments[idx] = updated);
    await _persist();
    await _notifications.cancel(_notificationId(updated));
    await _notifications.cancel(_reminderNotificationId(updated));
    await _scheduleNotification(updated);
  }

  // ---------------------------------------------------------------------------
  // Modals
  // ---------------------------------------------------------------------------
  void _openSyncModal() {
    showDialog(
      context: context,
      builder: (_) => CalendarSyncModal(
        onSyncSuccess: (count) {
          _speak('Calendário sincronizado! $count novos compromissos importados atendendo aos seus pedidos.');
        },
      ),
    );
  }

  void _openTutorialModal() {
    showDialog(
      context: context,
      builder: (_) => VoiceTutorialModal(speakText: _speak),
    );
  }

  void _openEmergencyModal() {
    showDialog(
      context: context,
      builder: (_) => EmergencyModal(speakText: _speak),
    );
  }

  void _openEditModal(Commitment c) {
    showDialog(
      context: context,
      builder: (_) => EditCommitmentModal(
        commitment: c,
        onSave: _editCommitment,
        speakText: _speak,
      ),
    );
  }

  void _openLockModal() {
    showDialog(
      context: context,
      builder: (_) => LockPinModal(
        isCurrentlyLocked: _isAgendaLocked,
        savedPin: _agendaPin,
        recoveryEmail: _recoveryEmail,
        recoveryPhone: _recoveryPhone,
        speakText: _speak,
        onSetupPin: (pin, email, phone) async {
          setState(() {
            _agendaPin = pin.isEmpty ? null : pin;
            _recoveryEmail = email.isEmpty ? null : email;
            _recoveryPhone = phone.isEmpty ? null : phone;
            _isAgendaLocked = pin.isNotEmpty;
          });
          final prefs = await SharedPreferences.getInstance();
          if (pin.isEmpty) {
            await prefs.remove('agendaPin');
            await prefs.remove('isAgendaLocked');
          } else {
            await prefs.setString('agendaPin', pin);
            await prefs.setBool('isAgendaLocked', true);
          }
          if (email.isEmpty) {
            await prefs.remove('agendaRecoveryEmail');
          } else {
            await prefs.setString('agendaRecoveryEmail', email);
          }
          if (phone.isEmpty) {
            await prefs.remove('agendaRecoveryPhone');
          } else {
            await prefs.setString('agendaRecoveryPhone', phone);
          }
        },
        onLock: () async {
          setState(() => _isAgendaLocked = true);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isAgendaLocked', true);
        },
        onUnlock: () async {
          setState(() => _isAgendaLocked = false);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isAgendaLocked', false);
        },
      ),
    );
  }

  void _openTechnicalReportModal() {
    showDialog(context: context, builder: (_) => const TechnicalReportModal());
  }

  void _openDiagnosticsModal() {
    showDialog(
      context: context,
      builder: (_) => AlarmDiagnosticsModal(
        speakText: _speak,
        onTestAlarm: _scheduleTestAlarm,
      ),
    );
  }

  void _scheduleTestAlarm() {
    final when = DateTime.now().add(const Duration(seconds: 20));
    _notifications.scheduleAlarm(
      id: 999999999,
      title: '🔔 Alarme de Teste',
      body: 'Este é o seu alarme de teste! Se você ouviu, todos os alarmes estão 100%.',
      scheduledTime: when,
      recurrence: null,
      payload: jsonEncode({'id': 'test', 'title': 'Alarme de Teste', 'time': '${when.hour.toString().padLeft(2,'0')}:${when.minute.toString().padLeft(2,'0')}'}),
    );
    _speak('Alarme de teste agendado para daqui a 20 segundos. Não desligue a tela. Vejamos se toca!');
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _deviceStatusBar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF4FDFB), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 12),
            _toolbar(),
            const SizedBox(height: 12),
            _statusStrip(),
            const SizedBox(height: 16),
            VoiceAssistant(
              onConfirmCommitment: (cmd) => _addCommitment(cmd),
              speakText: _speak,
              stopSpeech: _stopSpeech,
              isSpeaking: _isSpeaking,
            ),
            const SizedBox(height: 16),
            MonthlyCalendar(
              commitments: _commitments,
              selectedDate: _selectedDate,
              onSelectDate: (d) => setState(() => _selectedDate = d),
              speakText: _speak,
            ),
            const SizedBox(height: 16),
            CommitmentList(
              commitments: _commitments
                  .where((c) => ScheduleMatcher.occursOn(c, _selectedDate))
                  .toList(),
              selectedDate: _selectedDate,
              isLocked: _isAgendaLocked,
              onToggleComplete: (id) => _toggleComplete(id),
              onDelete: (id) => _deleteCommitment(id),
              onEdit: (c) => _openEditModal(c),
              speakText: _speak,
            ),
            const SizedBox(height: 20),
            _heartStrip(),
            const SizedBox(height: 8),
            _footer(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Device Status Bar — dynamic badges: mic, bell (24h count), wifi
  // ---------------------------------------------------------------------------
  Widget _deviceStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // Mic badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isSpeaking ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _isSpeaking ? Colors.red.shade200 : Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isSpeaking ? Icons.mic : Icons.mic_none,
                  size: 14,
                  color: _isSpeaking ? Colors.red.shade600 : Colors.green.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  _isSpeaking ? 'Mic Ativo' : 'Mic Pronto',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _isSpeaking ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Alarmes 24h badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_active, size: 14, color: Colors.indigo.shade600),
                const SizedBox(width: 4),
                Text(
                  'Alarmes Hoje: $_alarmCount24h',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header — exact match to web: logo + badge + buttons
  // ---------------------------------------------------------------------------
  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Logo row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF115E59)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '✦ Agenda Amiga (Voz)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Agenda Inteligente com Voz Natural 24h',
                    style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Action buttons row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _headerButton(Icons.sunny, 'Resumo do Dia', Colors.lightBlue, _welcomeAndBriefing),
            if (_isSpeaking)
              _headerButton(Icons.stop_circle, 'Parar Áudio', Colors.red, _stopSpeech),
            _headerButton(Icons.sync, 'Sincronizar', Colors.indigo, _openSyncModal),
            _headerButton(Icons.help_outline, '?', Colors.blueGrey, _openTutorialModal),
            _headerButton(Icons.hearing, 'Ajuda / Família', Colors.red, _openEmergencyModal),
          ],
        ),
      ],
    );
  }

  Widget _headerButton(IconData icon, String label, MaterialColor color, VoidCallback onTap) {
    return Material(
      color: color.shade50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color.shade700),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Toolbar — botões organizados lado a lado, compactos e elegantes
  // ---------------------------------------------------------------------------
  Widget _toolbar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Botão Trava da Agenda com status visual
          _toolChip(
            _isAgendaLocked ? Icons.lock : Icons.lock_open,
            _isAgendaLocked ? 'Agenda Trancada' : 'Trava / PIN',
            _openLockModal,
            bgColor: _isAgendaLocked ? Colors.amber.shade50 : Colors.white,
            borderColor: _isAgendaLocked ? Colors.amber.shade400 : Colors.teal.shade200,
            iconColor: _isAgendaLocked ? Colors.amber.shade800 : Colors.teal.shade700,
            textColor: _isAgendaLocked ? Colors.amber.shade900 : Colors.teal.shade800,
          ),
          const SizedBox(width: 8),
          _toolChip(Icons.record_voice_over, 'Voz', _openVoicePickerModal),
          const SizedBox(width: 8),
          _toolChip(Icons.build_circle, 'Diagnóstico', _openDiagnosticsModal),
          const SizedBox(width: 8),
          _toolChip(Icons.report_outlined, 'Relatório', _openTechnicalReportModal),
          const SizedBox(width: 8),
          _toolChip(Icons.sync, 'Sincronizar', _openSyncModal),
        ],
      ),
    );
  }

  Widget _toolChip(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? bgColor,
    Color? borderColor,
    Color? iconColor,
    Color? textColor,
  }) {
    return Material(
      color: bgColor ?? Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor ?? Colors.teal.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor ?? Colors.teal.shade700),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: textColor ?? Colors.teal.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status Strip — system operational 24h
  // ---------------------------------------------------------------------------
  Widget _statusStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.teal.shade600,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '● SISTEMA OPERACIONAL 24H — Assistente de voz ativo e protegendo você',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Heart Strip — protection message
  // ---------------------------------------------------------------------------
  Widget _heartStrip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: const Row(
        children: [
          Text('❤️', style: TextStyle(fontSize: 28)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Agenda Amiga Protegida — Funciona mesmo sem internet, com voz, remédios na hora certa e companhia o dia inteiro.',
              style: TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Footer — exact match to web
  // ---------------------------------------------------------------------------
  Widget _footer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.teal),
              children: [
                TextSpan(text: 'Agenda Amiga Protegida '),
                TextSpan(text: '❤️', style: TextStyle(fontSize: 13)),
                TextSpan(text: ' Operação 24h (Offline & Background)'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Desenvolvido por: JORCARD_JR',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade400),
          ),
        ],
      ),
    );
  }
}

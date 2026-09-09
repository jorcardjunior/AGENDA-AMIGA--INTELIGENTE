import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'package:alarm/alarm.dart';
import '../models/commitment.dart';
import '../scheduling/alarm_scheduler.dart';
import '../services/notification_service.dart';
import '../utils/date_formatter.dart';

// ---------------------------------------------------------------------------
// ALARM RINGING MODAL
// ---------------------------------------------------------------------------
class AlarmModal extends StatefulWidget {
  final String title;
  final String time;
  final String commitmentId;
  final Future<void> Function(String text) speakText;
  final VoidCallback stopSpeech;
  final VoidCallback onConfirmDone;
  final VoidCallback onSnooze;

  /// Intelligent, topic-aware announcement to speak instead of the raw title.
  /// When null, falls back to the legacy generic text.
  final String? announcement;

  /// When true this alarm is an advance reminder ("lembrete N dias antes"),
  /// so confirming must not mark the real commitment as done.
  final bool isReminderAlert;

  const AlarmModal({
    super.key,
    required this.title,
    required this.time,
    required this.commitmentId,
    required this.speakText,
    required this.stopSpeech,
    required this.onConfirmDone,
    required this.onSnooze,
    this.announcement,
    this.isReminderAlert = false,
  });

  @override
  State<AlarmModal> createState() => _AlarmModalState();
}

class _AlarmModalState extends State<AlarmModal> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  Timer? _relistenTimer;
  bool _ready = false;
  bool _ringing = false;
  bool _stopping = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _vibrate();
    _announceThenRing();
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  /// Anti-echo: speak first, and only AFTER the speech ends start the looping
  /// alarm-clock sound (despertador) and the mic. This way the alarm can never
  /// hear its own announcement (which contains the words "desligar"/"ok") and
  /// dismiss itself — only the user's voice stops it.
  Future<void> _announceThenRing() async {
    final smart = widget.announcement;
    final announcement = smart ?? 'Atenção! Hora do compromisso ou remédio: ${widget.title}.';
    final listenHint = 'Diga desligar, ok ou já ouvi para silenciar.';
    final text = '$announcement $listenHint';
    try {
      widget.stopSpeech();
      await Future.delayed(const Duration(milliseconds: 200));
      await widget.speakText(text);
    } catch (_) {}

    // O som do alarme é gerenciado nativamente pelo `alarm` package via
    // Foreground Service + STREAM_ALARM. Não usamos mais o audioplayers para
    // evitar conflitos de AudioFocus.
    if (!mounted) return;
    setState(() => _ringing = true);

    if (!_ready) {
      _ready = await _speech.initialize();
      if (!mounted || _stopping) return;
    }
    if (!_ready) return;

    _listenForStopCommand();
    // Keeps the mic on while the alarm rings: whenever a listen() session ends
    // (done/error/timeout), start it again until dismissed.
    _relistenTimer?.cancel();
    _relistenTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _stopping) {
        timer.cancel();
        return;
      }
      if (!_speech.isListening) {
        _listenForStopCommand();
      }
    });
  }

  /// Starts a single mic session. Called again by [_relistenTimer] whenever the
  /// session ends, so the user can always silence the ringing alarm by voice.
  Future<void> _listenForStopCommand() async {
    if (!mounted || _stopping) return;
    if (_speech.isListening) return;
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted || _stopping) return;
          final spoken = result.recognizedWords.toLowerCase();
          if (['desligar', 'fechar', 'fechado', 'chega', 'basta', 'já ouvi',
                  'ja ouvi', 'ok', 'obrigado', 'valeu', 'parar', 'sim', 'tomei']
              .any((w) => spoken.contains(w))) {
            _stopping = true;
            _relistenTimer?.cancel();
            _speech.stop();
            widget.stopSpeech();
            widget.onConfirmDone();
            widget.speakText('Alarme desligado com sucesso.');
            _dismiss();
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: 'pt_BR',
          listenFor: const Duration(seconds: 30),
        ),
      );
    } catch (_) {}
  }

  /// Stops the ringing alarm sound and closes the modal (idempotent).
  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    _stopping = true;
    _relistenTimer?.cancel();
    // Para o som do alarme via alarm package (Foreground Service nativo).
    final mainId = notificationIdFor(widget.commitmentId);
    try { await Alarm.stop(mainId); } catch (_) {}
    if (mounted) _close();
  }

  void _vibrate() {
    for (var i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: 500 * i), () {
        if (mounted) HapticFeedback.vibrate();
      });
    }
  }

  @override
  void dispose() {
    _relistenTimer?.cancel();
    _speech.stop();
    // Para o som do alarme nativo ao fechar o modal.
    final mainId = notificationIdFor(widget.commitmentId);
    Alarm.stop(mainId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF2B0A0A),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active, color: Colors.red, size: 52),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('ALARME DISPARADO AGORA',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
            const SizedBox(height: 12),
            // Ringing indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _ringing ? Colors.red.shade900 : Colors.red.shade500,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_active,
                      color: _ringing ? Colors.red.shade200 : Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _ringing ? '🔔 TOCANDO... Fale "Ok" ou "Desligar"' : 'Anunciando...',
                    style: TextStyle(
                      color: _ringing ? Colors.red.shade100 : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              'Horário: ${widget.time}',
              style: const TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Você pode dizer "Desligar", "Já ouvi" ou "Ok", ou tocar no botão abaixo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.stopSpeech();
                  widget.onConfirmDone();
                  widget.speakText(widget.isReminderAlert
                      ? 'Perfeito. Ainda vai dar tempo de se preparar. Nada de esquecimento!'
                      : 'Remédio tomado e registrado.');
                  _dismiss();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.check_circle),
                label: Text(widget.isReminderAlert
                    ? 'Já Sei, Obrigado!'
                    : 'Já Tomei / Realizei!',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  widget.stopSpeech();
                  widget.speakText('Alarme adiado por 10 minutos.');
                  widget.onSnooze();
                  _dismiss();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Adiar por 10 Minutos', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CALENDAR SYNC MODAL
// ---------------------------------------------------------------------------
class CalendarSyncModal extends StatefulWidget {
  final void Function(int count) onSyncSuccess;
  const CalendarSyncModal({super.key, required this.onSyncSuccess});

  @override
  State<CalendarSyncModal> createState() => _CalendarSyncModalState();
}

class _CalendarSyncModalState extends State<CalendarSyncModal> {
  bool _syncing = false;
  String? _syncedFrom;

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  void _handleSync(String provider, int count) {
    setState(() => _syncing = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _syncedFrom = provider;
      });
      widget.onSyncSuccess(count);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.calendar_month, color: Colors.indigo, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sincronizar Calendários',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      Text('Google Calendar & Apple iCal', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _close,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Importe automaticamente consultas médicas e compromissos salvos no seu celular ou conta Google para que a Agenda Amiga avise você em voz alta na hora certa.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            if (_syncedFrom != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.teal),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Sincronização Concluída! Seus compromissos externos foram importados com sucesso.',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              )
            else ...[
              _syncButton('Conectar Google Calendar', 'Sincronizar eventos da conta Google', () => _handleSync('Google', 3), _syncing),
              const SizedBox(height: 12),
              _syncButton('Conectar Apple Calendar (iCal)', 'Sincronizar eventos do iPhone / iCloud', () => _handleSync('Apple', 2), _syncing),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _close,
                  child: const Text('Concluir', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncButton(String title, String subtitle, VoidCallback onTap, bool disabled) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueGrey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(disabled ? Icons.sync : Icons.link, color: Colors.indigo, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
            ),
            if (disabled)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.indigo),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VOICE TUTORIAL MODAL
// ---------------------------------------------------------------------------
class VoiceTutorialModal extends StatelessWidget {
  final void Function(String) speakText;
  const VoiceTutorialModal({super.key, required this.speakText});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.help, color: Colors.lightBlue, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Como Usar a Agenda por Voz',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      Text('Guia rápido e simples', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _tutorialItem(Icons.mic, Colors.lightBlue, '1. Toque no Grande Microfone',
                'Basta tocar no botão redondo verde no centro da tela e falar o que você precisa lembrar. Não se preocupe se errar o horário, nossa inteligência artificial ajusta para você!'),
            const SizedBox(height: 12),
            _tutorialItem(Icons.volume_up, Colors.teal, '2. Avisos e Lembretes em Voz Alta',
                'O aplicativo fala com você em voz alta quando chegar a hora do compromisso ou do remédio. Você também pode tocar no alto-falante ao lado de qualquer tarefa para ouvir novamente.'),
            const SizedBox(height: 12),
            _tutorialItem(Icons.emoji_events, Colors.amber, '3. Jardim da Vida (Gamificação)',
                'Cada tarefa cumprida rega seu jardim virtual e faz lindas flores desabrocharem, trazendo alegria e parabéns carinhosos todos os dias!'),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => speakText(
                      'Bem-vindo à Agenda Amiga. Basta tocar no microfone e falar o que deseja lembrar.'),
                  icon: const Icon(Icons.volume_up, color: Colors.lightBlue),
                  label: const Text('Ouvir Explicação em Voz',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlue)),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido, Vamos Começar!', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tutorialItem(IconData icon, Color color, String title, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// EMERGENCY / "Ajuda / Família" MODAL — up to 5 caregiver contacts
// ---------------------------------------------------------------------------
class _CaregiverContact {
  final String name;
  final String phone;

  const _CaregiverContact({required this.name, required this.phone});

  factory _CaregiverContact.fromJson(Map<String, dynamic> json) =>
      _CaregiverContact(
        name: (json['name'] ?? '') as String,
        phone: (json['phone'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
}

class EmergencyModal extends StatefulWidget {
  final void Function(String) speakText;
  const EmergencyModal({super.key, required this.speakText});

  @override
  State<EmergencyModal> createState() => _EmergencyModalState();
}

class _EmergencyModalState extends State<EmergencyModal> {
  static const int _maxContacts = 5;
  static const String _prefsKey = 'caregiver_contacts';

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<_CaregiverContact> _contacts = [];
  bool _sent = false;
  bool _showForm = false;
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) {
      _contacts = [
        _CaregiverContact(name: 'Maria (Filha)', phone: '11998887766'),
      ];
    } else if (raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _contacts = list
            .map((e) => _CaregiverContact.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _contacts = [];
      }
    }
    if (mounted) setState(() {});
  }

  /// Scrolls the modal to the very bottom so the action buttons stay visible
  /// even with the soft keyboard open on small screens.
  void _scrollToActions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final maxExtent = _scrollCtrl.position.maxScrollExtent;
      if (maxExtent > 0) {
        _scrollCtrl.animateTo(
          maxExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(_contacts.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveContact() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (name.isEmpty || phone.isEmpty) {
      widget.speakText('Informe o nome e o telefone do contato.');
      return;
    }
    bool rejected = false;
    setState(() {
      if (_editingIndex != null &&
          _editingIndex! >= 0 &&
          _editingIndex! < _contacts.length) {
        _contacts[_editingIndex!] = _CaregiverContact(name: name, phone: phone);
      } else if (_contacts.length < _maxContacts) {
        _contacts.add(_CaregiverContact(name: name, phone: phone));
      } else {
        rejected = true;
      }
      _showForm = rejected ? true : false;
      _editingIndex = null;
      _nameCtrl.clear();
      _phoneCtrl.clear();
    });
    if (rejected) {
      widget.speakText(
          'Limite de $_maxContacts contatos atingido. Remova um contato antes de adicionar outro.');
      return;
    }
    await _saveContacts();
    widget.speakText('Contato de $name salvo para chamadas de emergência.');
  }

  void _startAdd() {
    setState(() {
      _editingIndex = null;
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _showForm = true;
    });
    _scrollToActions();
  }

  void _startEdit(int index) {
    setState(() {
      _editingIndex = index;
      _nameCtrl.text = _contacts[index].name;
      _phoneCtrl.text = _contacts[index].phone;
      _showForm = true;
    });
    _scrollToActions();
  }

  void _deleteContact(int index) {
    setState(() {
      _contacts.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
        _showForm = false;
        _nameCtrl.clear();
        _phoneCtrl.clear();
      }
    });
    _saveContacts();
    widget.speakText('Contato removido.');
    if (_contacts.isEmpty) _startAdd();
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _handleAlert() async {
    if (_contacts.isEmpty) return;
    final primary = _contacts.first;
    setState(() => _sent = true);
    widget.speakText(
        'Mensagem de aviso enviada para ${primary.name}. Ela ou ele ligará em instantes.');
    await _call(primary.phone);
  }

  Future<void> _callEmergency(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 700),
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone, color: Colors.red, size: 40),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Contato com Familiar / Cuidador',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 6),
              const Text(
                  'Precisa de ajuda ou quer avisar que esqueceu de algo? Cadastre até 5 parentes ou cuidadores e ligue com um toque.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 16),
              if (_sent)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.teal, size: 36),
                      const SizedBox(height: 6),
                      const Text('Aviso Enviado com Sucesso!',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                          '${_contacts.isEmpty ? 'O contato' : _contacts.first.name} recebeu uma notificação urgente no celular.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          label: const Text('Fechar'),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // ---------------------------------------------------------
                // Contacts list header
                // ---------------------------------------------------------
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.blueGrey, size: 18),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('SEUS CONTATOS DE AJUDA',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.blueGrey)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${_contacts.length}/$_maxContacts',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.red.shade700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ---------------------------------------------------------
                // Contact rows
                // ---------------------------------------------------------
                if (_contacts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Nenhum contato cadastrado ainda. Toque em "Adicionar Contato" abaixo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  )
                else
                  ..._contacts.asMap().entries.map((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    return _contactRow(i, c);
                  }),
                const SizedBox(height: 10),
                // ---------------------------------------------------------
                // Add/Edit form
                // ---------------------------------------------------------
                if (_showForm)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _editingIndex != null
                              ? 'EDITAR CONTATO'
                              : 'NOVO CONTATO',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.blueGrey.shade700),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _contactField('Nome (ex: Maria - Filha)'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: _contactField('Telefone (ex: 11998887766)'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() {
                                  _showForm = false;
                                  _editingIndex = null;
                                  _nameCtrl.clear();
                                  _phoneCtrl.clear();
                                }),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _saveContact,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Salvar',
                                    style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else if (_contacts.length < _maxContacts)
                  OutlinedButton.icon(
                    onPressed: _startAdd,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Adicionar Parente / Cuidador'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal.shade700,
                      side: const BorderSide(color: Colors.teal),
                    ),
                  ),
                const SizedBox(height: 16),
                // ---------------------------------------------------------
                // SOS button
                // ---------------------------------------------------------
                ElevatedButton.icon(
                  onPressed: _handleAlert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.send),
                  label: const Text('Chamar / Enviar SOS Agora',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _callEmergency('192'),
                        icon: const Icon(Icons.local_hospital, size: 18),
                        label: const Text('SAMU 192',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _callEmergency('190'),
                        icon: const Icon(Icons.local_police, size: 18),
                        label: const Text('Polícia 190',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactRow(int index, _CaregiverContact contact) {
    final initial = contact.name.isNotEmpty
        ? contact.name[0].toUpperCase()
        : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.teal.shade100,
            child: Text(initial,
                style: TextStyle(
                    color: Colors.teal.shade800,
                    fontWeight: FontWeight.w900,
                    fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 14)),
                Text(contact.phone,
                    style: TextStyle(
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit, size: 18, color: Colors.blueGrey),
            onPressed: () => _startEdit(index),
          ),
          IconButton(
            tooltip: 'Excluir',
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            onPressed: () => _deleteContact(index),
          ),
          IconButton(
            tooltip: 'Ligar agora',
            icon: const Icon(Icons.call, color: Colors.teal),
            onPressed: () => _call(contact.phone),
          ),
        ],
      ),
    );
  }

  InputDecoration _contactField(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ---------------------------------------------------------------------------
// EDIT COMMITMENT MODAL
// ---------------------------------------------------------------------------
class EditCommitmentModal extends StatefulWidget {
  final Commitment commitment;
  final void Function(Commitment) onSave;
  final void Function(String) speakText;

  const EditCommitmentModal({
    super.key,
    required this.commitment,
    required this.onSave,
    required this.speakText,
  });

  @override
  State<EditCommitmentModal> createState() => _EditCommitmentModalState();
}

class _EditCommitmentModalState extends State<EditCommitmentModal> {
  late TextEditingController _title;
  late DateTime _date;
  late String _time;
  late String _priority;
  late String _category;
  late String _recurrence;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.commitment.title);
    _date = DateFormatter.parseDate(widget.commitment.date);
    _time = widget.commitment.time;
    _priority = widget.commitment.priority;
    _category = widget.commitment.category;
    _recurrence = widget.commitment.recurrence ?? 'Único';
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        _time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    final dateStr = DateFormatter.toDateStr(_date);
    final updated = widget.commitment.copyWith(
      title: _title.text.trim(),
      date: dateStr,
      time: _time,
      priority: _priority,
      category: _category,
      recurrence: _recurrence,
      recurrenceDayOfMonth:
          _recurrence == 'Mensal' ? _date.day : null,
      recurrenceDaysOfWeek: _recurrence == 'Dias da semana'
          ? widget.commitment.recurrenceDaysOfWeek
          : null,
      correctionNote: 'Editado e atualizado.',
    );
    widget.onSave(updated);
    widget.speakText(
        'Compromisso ${updated.title} atualizado para o dia ${DateFormatter.formatNaturalDate(dateStr)} às ${updated.time}.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.calendar_month, color: Colors.teal, size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Editar Compromisso', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      Text('Altere os dados do lembrete ou remédio', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: 'Título do Compromisso / Remédio',
                filled: true,
                fillColor: Colors.blueGrey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Data',
                        filled: true,
                        fillColor: Colors.blueGrey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      child: Text(DateFormatter.formatShort(_date)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Horário',
                        filled: true,
                        fillColor: Colors.blueGrey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      child: Text(_time),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: _fieldDecoration('Prioridade'),
              items: const ['Alta', 'Média', 'Baixa']
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: _fieldDecoration('Categoria'),
              items: const ['Saúde/Remédio', 'Consulta', 'Família', 'Casa', 'Outros']
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _recurrence,
              decoration: _fieldDecoration('Recorrência'),
              items: const [
                    'Único',
                    'Todos os dias',
                    'Semanal',
                    'Mensal',
                    'A cada 3 dias',
                    'De hora em hora'
                  ]
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _recurrence = v!),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.blueGrey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );
  }
}

// ---------------------------------------------------------------------------
// TECHNICAL REPORT MODAL
// ---------------------------------------------------------------------------
class TechnicalReportModal extends StatelessWidget {
  const TechnicalReportModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 800),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.teal.shade300, width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.description, color: Colors.teal.shade700, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Relatório Técnico & Análise de Usabilidade',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.teal)),
                        Text('Agenda Inteligente Acessível (SeniorCare Voice)',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Executive Summary
                      _section(
                        icon: Icons.favorite,
                        color: Colors.teal,
                        title: '1. Sumário Executivo e Missão',
                        child: const Text(
                          'Este relatório apresenta a arquitetura e diretrizes de usabilidade para o desenvolvimento de uma agenda 100% controlada por voz e adaptada para idosos e pessoas com esquecimento frequente ou baixa afinidade tecnológica. O objetivo é eliminar barreiras digitais através de comandos de voz naturais, correção inteligente de horários confusos e feedback multissensorial (voz, som e push em tempo real).',
                          style: TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 2. Accessibility Recommendations
                      _section(
                        icon: Icons.visibility,
                        color: Colors.teal,
                        title: '2. Recomendações de Usabilidade e Acessibilidade',
                        child: Column(
                          children: [
                            _cardTile(Icons.touch_app, 'Interface Minimalista & Botões Gigantes',
                                'Eliminação completa de menus complexos e submenus aninhados. Todos os alvos de toque possuem dimensões mínimas de 64x64px com espaçamento generoso para evitar toques acidentais por tremores ou baixa coordenação motora.'),
                            const SizedBox(height: 8),
                            _cardTile(Icons.mic, 'Navegação e Comando 100% por Voz',
                                'O usuário pode falar naturalmente. O sistema interpreta e corrige automaticamente inversões de horário e confirma em voz alta com tom acolhedor.'),
                            const SizedBox(height: 8),
                            _cardTile(Icons.priority_high, 'Priorização Inteligente de Tarefas',
                                'Classificação automática em 3 níveis visuais e sonoros: 🔴 Alta (Saúde/Remédios), 🟡 Média (Consultas/Família) e 🟢 Baixa (Rotina Casa).'),
                            const SizedBox(height: 8),
                            _cardTile(Icons.sync, 'Sincronização com Calendários Existentes',
                                'Integração nativa com Google Calendar e Apple Calendar para unificar compromissos médicos e familiares já cadastrados pela família sem esforço do usuário final.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 3. Gamification Ideas (informational only, not implemented)
                      _section(
                        icon: Icons.emoji_events,
                        color: Colors.amber,
                        title: '3. Ideias para Gamificação e Engajamento de Idosos',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Para idosos, a gamificação não deve ser competitiva ou estressante, mas sim focada em gratificação emocional, progresso visual e conexão afetiva:',
                              style: TextStyle(fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            _bulletItem('O Jardim da Vida: cada tarefa cumprida rega uma plantinha virtual.'),
                            _bulletItem('Mensagens de Voz Carinhosas da Família ao atingir 100% das tarefas.'),
                            _bulletItem('Troféus de Superação com design nostálgico e explicações em áudio.'),
                            _bulletItem('Sequência de Dias Felizes (Streak) representada por um sol sorridente.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 4. Offline AI Technologies
                      _section(
                        icon: Icons.memory,
                        color: Colors.blue,
                        title: '4. Tecnologias de IA Offline e Vozes Neurais',
                        child: Column(
                          children: [
                            _cardTile(Icons.psychology, 'ONNX Runtime + Transformers.js',
                                'Permite rodar modelos compactos de linguagem diretamente no dispositivo móvel para interpretar comandos de voz sem enviar dados para a nuvem.'),
                            const SizedBox(height: 8),
                            _cardTile(Icons.record_voice_over, 'Piper TTS / Sherpa-onnx',
                                'Biblioteca que gera síntese de voz neural em português do Brasil com entonação humana natural, sem necessidade de conexão com a internet.'),
                            const SizedBox(height: 8),
                            _cardTile(Icons.alarm, 'Background Workers & AlarmManager',
                                'Uso de APIs nativas de agendamento de alarmes e notificações locais push em tempo real garantindo que o aviso sonoro toque no horário exato.'),
                            const SizedBox(height: 8),
                            _cardTile(Icons.storage, 'SQLite Local + Ferramentas de Fuso Horário',
                                'Banco de dados local ultra-rápido para persistir compromissos recorrentes mantendo a consistência de datas e horários.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido, Voltar à Agenda', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required IconData icon, required Color color, required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _cardTile(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.teal.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ALARM DIAGNOSTICS MODAL
// ---------------------------------------------------------------------------
/// Opens in-app to let the (often elderly) user see **exactly** what is
/// preventing their alarm from ringing, and fix it in one or two taps.
class AlarmDiagnosticsModal extends StatefulWidget {
  final void Function(String) speakText;
  final VoidCallback onTestAlarm;

  const AlarmDiagnosticsModal({
    super.key,
    required this.speakText,
    required this.onTestAlarm,
  });

  @override
  State<AlarmDiagnosticsModal> createState() => _AlarmDiagnosticsModalState();
}

class _AlarmDiagnosticsModalState extends State<AlarmDiagnosticsModal> {
  final _ns = NotificationService();
  bool _loading = true;
  bool? _notifEnabled;
  bool? _exactAllowed;
  bool? _batteryOk;
  Map<String, dynamic> _channelInfo = {};
  bool _testScheduled = false;
  bool _soundTested = false;
  bool _defaultNotifSent = false;
  String _brand = 'Android';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await _ns.alarmPermissionsStatus();
    final brand = await _ns.deviceBrand();
    final batteryOk = await _ns.isIgnoringBatteryOptimizations();
    final channelInfo = await _ns.isChannelEnabled(NotificationService.alarmChannelId);
    if (mounted) {
      setState(() {
        _notifEnabled = status['notificationsEnabled'];
        _exactAllowed = status['exactAlarmAllowed'];
        _batteryOk = batteryOk;
        _channelInfo = channelInfo;
        _brand = brand;
        _loading = false;
      });
    }
  }

  /// Posts an IMMEDIATE notification on the new alarm channel. If the user
  /// does not hear the sound, the cause is either an old muted channel (fixed
  /// by the versioned channel id) or the phone's alarm volume — not the code.
  Future<void> _testSoundNow() async {
    await _ns.showImmediate(
      id: 999999997,
      title: '🔊 Teste de Som',
      body: 'Este é o som do alarme. Se você ouviu, o som está funcionando!',
    );
    setState(() => _soundTested = true);
    widget.speakText(
        'Toquei o som do alarme agora. Se você ouviu, o som está perfeito. Se não ouviu, aumente o volume de alarme do celular.');
  }

  Future<void> _requestExact() async {
    await _ns.requestExactAlarmPermission();
    await _refresh();
  }

  Future<void> _openNotifSettings() async {
    await _ns.openAppNotificationSettings();
    await _refresh();
  }

  Future<void> _requestBatteryWhitelist() async {
    await _ns.requestBatteryWhitelist();
    await _refresh();
  }

  Future<void> _sendDefaultNotif() async {
    await _ns.testDefaultNotification();
    setState(() => _defaultNotifSent = true);
    widget.speakText(
        'Enviei uma notificação direta do Android. Se você vê e ouve ela, '
        'o Android funciona. O problema é nosso canal de alarme ou o agendamento.');
  }

  Future<void> _openChannelSettings() async {
    await _ns.openChannelSettings(NotificationService.alarmChannelId);
    await _refresh();
  }

  String _friendlyScheduleResult(String r) {
    switch (r) {
      case 'alarmClock':
        return '✅ alarmClock (o mais confiável)';
      case 'inexact':
        return '⚠️ inexact (pode atrasar)';
      case 'immediate_fallback':
        return '🔴 apareceu imediatamente (agendamento falhou!)';
      case 'all_failed':
        return '❌ TODOS os métodos falharam';
      case 'not_called_yet':
        return 'Ainda não agendou nada';
      default:
        return r;
    }
  }

  void _scheduleTest() {
    widget.onTestAlarm();
    setState(() => _testScheduled = true);
    widget.speakText(
        'Alarme de teste agendado para daqui a 20 segundos. Se você não ouvir nada, o Android está bloqueando. Clique em Resolver para permitir alarmes exatos.');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.build_circle, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Diagnóstico de Alarmes',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            if (_loading) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              const SizedBox(height: 16),
              _statusRow(
                ok: _notifEnabled == true,
                label: 'Notificações do Android',
                detail: _notifEnabled == true
                    ? 'Permitidas — o alarme pode aparecer'
                    : 'Bloqueadas — o alarme NÃO pode aparecer!',
                fixLabel: _notifEnabled == true ? 'Configurar' : 'Permitir Agora',
                onFix: _openNotifSettings,
              ),
              const SizedBox(height: 12),
              _statusRow(
                ok: _exactAllowed == true,
                label: 'Alarme Exato',
                detail: _exactAllowed == true
                    ? 'Permitido — alarme toca na hora exata'
                    : 'Bloqueado — o alarme pode atrasar ou NÃO TOCAR!',
                fixLabel: _exactAllowed == true ? 'Configurar' : 'Permitir Agora',
                onFix: _requestExact,
              ),
              const SizedBox(height: 12),
              // The REAL block on OEMs (realme/OPPO/Xiaomi): the app is in the
              // "queima bateria" bucket and gets frozen — green permissions
              // above mean nothing then.
              _statusRow(
                ok: _batteryOk == true,
                label: 'Economia de bateria (bloqueio da realme/OPPO)',
                detail: _batteryOk == true
                    ? 'Liberado — o Android não congela os alarmes'
                    : 'Bloqueado! O celular está congelando o app e os alarmes podem NUNCA tocar',
                fixLabel: _batteryOk == true ? 'Configurar' : 'Permitir Agora',
                onFix: _requestBatteryWhitelist,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _ns.openAutostartSettings(),
                  icon: const Icon(Icons.autorenew, color: Colors.teal),
                  label: const Text(
                    'Abrir autorização de "Iniciar automaticamente" (autostart)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.teal),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _ns.openBatteryManager(),
                  icon: const Icon(Icons.battery_5_bar, color: Colors.teal),
                  label: const Text(
                    'Abrir "Gerenciamento de bateria de apps" (não otimizar)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.teal),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ── EXAME CLÍNICO: canal de notificação ─────────────────
              // This is THE diagnostic that was missing: permissions can be
              // green while the notification channel is muted/broken at the
              // OS level — the #1 hidden cause on OEMs.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.medical_services, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text('Exame Clínico do Alarme',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    // Channel status
                    _statusRow(
                      ok: _channelInfo['enabled'] == true,
                      label: 'Canal de notificação (agenda_amiga_alarms_v2)',
                      detail: _channelInfo['exists'] == false
                          ? 'Canal NÃO EXISTE — nenhum alarme pode aparecer!'
                          : _channelInfo['enabled'] == true
                              ? 'Ativo — importance: ${_channelInfo['importance']}, '
                                'som: ${_channelInfo['hasSound'] == true ? 'sim' : 'NÃO'}'
                              : 'DESABILITADO no Android — nenhum alarme pode aparecer!',
                      fixLabel: _channelInfo['enabled'] == true ? 'Configurar canal' : 'Abrir e ativar',
                      onFix: _openChannelSettings,
                    ),
                    const SizedBox(height: 8),
                    // Last schedule result
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _ns.lastScheduleResult == 'all_failed'
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _ns.lastScheduleResult == 'all_failed'
                                ? Icons.error
                                : Icons.info_outline,
                            color: _ns.lastScheduleResult == 'all_failed'
                                ? Colors.red
                                : Colors.green.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Último agendamento: ${_friendlyScheduleResult(_ns.lastScheduleResult)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _ns.lastScheduleResult == 'all_failed'
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Test on DEFAULT channel (bypasses our custom channel)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _defaultNotifSent ? null : _sendDefaultNotif,
                        icon: Icon(
                          _defaultNotifSent ? Icons.check_circle : Icons.notifications_active,
                          color: _defaultNotifSent ? Colors.green : Colors.blue,
                        ),
                        label: Text(
                          _defaultNotifSent
                              ? 'Notificação padrão enviada! Verifique acima ☝️'
                              : '🔔 Testar notificação do Android (padrão)',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Se a notificação PADRÃO acima aparece mas o alarme NÃO toca, '
                      'toque em "Configurar canal" acima e veja se o canal está '
                      'desabilitado ou sem som. Toque em "Atualizar" ao voltar.',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Brand-specific anti-kill guidance (the REAL cause on OEMs).
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.phone_android, color: Colors.amber.shade800, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Permitir no seu $_brand (1 vez só)',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    ..._brandSteps(_brand),
                    const SizedBox(height: 4),
                    Text(
                      'Se as permissões acima estão verdes e o alarme ainda não toca, '
                      'são estes passos de $_brand que autorizam o alarme a tocar '
                      'com a tela desligada.',
                      style: TextStyle(fontSize: 11, height: 1.4, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _soundTested ? null : _testSoundNow,
                  icon: Icon(_soundTested ? Icons.check_circle : Icons.volume_up,
                      color: _soundTested ? Colors.green : Colors.teal),
                  label: Text(
                    _soundTested ? 'Som do alarme testado!' : '🔊 Testar Som do Alarme Agora',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.teal),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _testScheduled ? null : _scheduleTest,
                  icon: Icon(_testScheduled ? Icons.check_circle : Icons.notification_important,
                      color: Colors.white),
                  label: Text(
                    _testScheduled ? 'Alarme de teste disparando...' : '🔔 Testar Alarme em 20 segundos',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Se o alarme de teste tocar, está tudo funcionando. Se não tocar, '
              'siga o passo a passo do seu celular acima e reinicie o aparelho.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow({
    required bool ok,
    required String label,
    required String detail,
    required String fixLabel,
    required VoidCallback onFix,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ok ? Colors.green.shade200 : Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error, color: ok ? Colors.green : Colors.red, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(detail, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onFix,
            child: Text(fixLabel,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ok ? Colors.blueGrey : Colors.teal)),
          ),
        ],
      ),
    );
  }

  /// Brand-specific steps so the alarm survives the OEM's battery killer.
  /// Based on the community-maintained dontkillmyapp.com guides.
  List<Widget> _brandSteps(String brand) {
    final b = brand.toLowerCase();
    final steps = <String>[
      if (b.contains('samsung'))
        ...{
          '1. Configurações > Cuidados com o aparelho > Bateria',
          '2. Toque em "Limites de uso em segundo plano"',
          '3. Abaixo de "Apps que nunca serão suspensos", ative Agenda Amiga',
          '4. Em Configurações > Apps > Agenda Amiga > Bateria, escolha "Sem restrição"',
        }
      else if (b.contains('xiaomi') || b.contains('redmi') || b.contains('poco'))
        ...{
          '1. Aplicativo Segurança > Otimização',
          '2. Toque no ícone de engrenagem > "Restringir apps em segundo plano"',
          '3. Desative Agenda Amiga nessa lista',
          '4. Segurança > Permissões > Auto-início > ative Agenda Amiga',
        }
      else if (b.contains('realme'))
        ...{
          '1. Configurações > Bateria > Economia de energia > Gerenciamento de bateria de apps > Agenda Amiga',
          '2. Ative: Auto-início, Atividade em primeiro plano e Atividade em segundo plano',
          '3. Em "Otimizar o uso da bateria", escolha "Não otimizar"',
          '4. Configurações > Apps > Acesso especial > "Mostrar janelas sobre apps em segundo plano" > ative Agenda Amiga',
          '5. Garanta que Agenda Amiga NÃO esteja em "Congelamento rápido de apps"',
          '6. Nas abas recentes: segure o cartão da Agenda Amiga > toque no cadeado para travar',
        }
      else if (b.contains('oppo'))
        ...{
          '1. Configurações > Bateria > Otimização da bateria',
          '2. Encontre Agenda Amiga e escolha "Permitir" (não otimizado)',
          '3. Configurações > Apps > Agenda Amiga > "Permitir auto-início"',
        }
      else if (b.contains('motorola') || b.contains('moto'))
        ...{
          '1. Configurações > Bateria > Otimização da bateria',
          '2. Toque em "Não otimizado" e selecione Agenda Amiga',
        }
      else if (b.contains('huawei') || b.contains('honor'))
        ...{
          '1. Configurações > Baterias > Otimização de bateria',
          '2. Aplicativos > Agenda Amiga > "Não otimizado"',
          '3. Configurações > Apps > Agenda Amiga > Ativar "Executar em segundo plano"',
        }
      else
        ...{
          '1. Configurações do celular > Bateria',
          '2. Procure "Otimização de bateria" ou "Apps em segundo plano"',
          '3. Selecione Agenda Amiga e escolha "Não otimizado" / "Sem restrição"',
        },
    ];
    return steps
        .map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(s, style: const TextStyle(fontSize: 12, height: 1.35)),
            ))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// VOICE PICKER MODAL — let the user choose WHICH voice speaks their agenda
// ---------------------------------------------------------------------------
/// Lists every Portuguese voice the Android TTS engine offers (frequently the
/// engine has a feminine and a masculine voice) and lets the elderly user pick
/// the one they understand best. Choice is persisted and reapplied on start.
class VoicePickerModal extends StatefulWidget {
  final FlutterTts tts;
  final String? currentVoice;
  final void Function(String) speakText;
  final Future<void> Function(String stored, Map<String, String> voice) onSelected;

  const VoicePickerModal({
    super.key,
    required this.tts,
    required this.currentVoice,
    required this.speakText,
    required this.onSelected,
  });

  @override
  State<VoicePickerModal> createState() => _VoicePickerModalState();
}

class _Voice {
  final String label;
  final Map<String, String> voiceParams;
  const _Voice(this.label, this.voiceParams);
}

class _VoicePickerModalState extends State<VoicePickerModal> {
  List<_Voice> _voices = [];
  bool _loading = true;
  String? _activeStored;

  @override
  void initState() {
    super.initState();
    _activeStored = widget.currentVoice;
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await widget.tts.getVoices;
      final list = <_Voice>[];
      if (raw != null) {
        for (final v in raw) {
          if (v is Map) {
            final name = v['name']?.toString() ?? '';
            final locale = v['locale']?.toString() ?? v['voiceLocaleId']?.toString() ?? '';
            if (name.isEmpty) continue;
            // Prefer Portuguese voices, but keep every voice visible so the
            // user always finds the one they recognize.
            list.add(_Voice(_friendly(name, locale), {
              'name': name,
              'locale': locale,
            }));
          }
        }
      }
      // Keep only Portuguese voices (pt / pt-BR / pt-PT / ptp etc.) so the
      // elderly user is never confused by dozens of non-Portuguese voices.
      final seen = <String>{};
      final pt = <_Voice>[];
      for (final v in list) {
        final l = v.voiceParams['locale']?.toLowerCase() ?? '';
        if (!l.startsWith('pt')) continue;
        final key = '${v.voiceParams['name']}|${v.voiceParams['locale']}';
        if (seen.contains(key)) continue;
        seen.add(key);
        pt.add(v);
      }
      _voices = [
        const _Voice('Voz padrão do celular', {'name': '', 'locale': ''}),
        ...pt,
      ];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  static String _friendly(String name, String locale) {
    final low = name.toLowerCase();
    final feminino = low.contains('fem') || low.contains('_f');
    final masculino = low.contains('masc') || low.contains('masculine');
    final feminine =
        feminino || low.contains('female') || low.contains('f-') || low.contains('-f');
    final masculine =
        masculino || low.contains('male') || low.contains('-m') || low.contains('_m');
    var label = name.split(' ').take(3).join(' ');
    if (feminine) label = '$label • Voz feminina';
    if (masculine) label = '$label • Voz masculina';
    final loc = locale.split('-');
    if (loc.length >= 2) label = '$label • ${loc[0]}-${loc[1].toUpperCase()}';
    return label;
  }

  String _stored(Map<String, String> voice) =>
      jsonEncode({'name': voice['name'], 'locale': voice['locale']});

  bool _isActive(_Voice v) {
    if (v.voiceParams['name']!.isEmpty) {
      return _activeStored == null || _activeStored == _stored(v.voiceParams);
    }
    return _activeStored == _stored(v.voiceParams);
  }

  Future<void> _pick(_Voice v) async {
    final stored = _stored(v.voiceParams);
    setState(() => _activeStored = stored);
    try {
      if (v.voiceParams['name']!.isEmpty) {
        // Reset to the engine default.
        final def = await widget.tts.getDefaultVoice;
        if (def is Map && def['name'] != null) {
          await widget.tts.setVoice({
            'name': def['name'].toString(),
            'locale': def['locale']?.toString() ?? 'pt-BR',
          });
        }
      } else {
        await widget.tts.setVoice(v.voiceParams);
      }
      await widget.onSelected(stored, v.voiceParams);
    } catch (_) {
      await widget.onSelected(stored, v.voiceParams);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.record_voice_over, color: Color(0xFF0D9488), size: 24),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Escolher a Voz',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        Text('Toque na voz para ouvir como vou falar',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  : _voices.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Nenhuma voz adicional encontrada neste celular.\n'
                              'Uma só voz será usada.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _voices.length,
                          itemBuilder: (context, i) {
                            final v = _voices[i];
                            final active = _isActive(v);
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                active ? Icons.priority_high : Icons.volume_up,
                                color: active ? const Color(0xFF0D9488) : Colors.grey,
                              ),
                              title: Text(
                                v.label,
                                style: TextStyle(
                                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                                    fontSize: 13),
                              ),
                              trailing: active
                                  ? const Icon(Icons.check_circle, color: Color(0xFF0D9488))
                                  : null,
                              onTap: () => _pick(v),
                            );
                          },
                        ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Esta configuração também vale para os alarmes: a voz escolhida '
                      'anuncia os compromissos.',
                      style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
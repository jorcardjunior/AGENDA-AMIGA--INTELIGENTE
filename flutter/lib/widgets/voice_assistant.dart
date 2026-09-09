import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../intelligence/announcer.dart';
import '../models/commitment.dart';
import '../parser/natural_command_parser.dart';
import '../utils/date_formatter.dart';

class VoiceAssistant extends StatefulWidget {
  final void Function(ParsedCommand command) onConfirmCommitment;
  final void Function(String) speakText;
  final VoidCallback stopSpeech;
  final bool isSpeaking;

  const VoiceAssistant({
    super.key,
    required this.onConfirmCommitment,
    required this.speakText,
    required this.stopSpeech,
    this.isSpeaking = false,
  });

  @override
  State<VoiceAssistant> createState() => _VoiceAssistantState();
}

class _VoiceAssistantState extends State<VoiceAssistant> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();

bool _isListening = false;
  bool _speechReady = false;
  bool _handledSession = false;
  String _transcript = '';
  ParsedCommand? _pending;
  String? _statusMessage;

  static const List<String> _confirmWords = [
    'sim', 'quero', 'quero sim', 'ok', 'pode', 'pode sim', 'pode marcar', 'pode agendar',
    'confirmo', 'confirma', 'confirmado', 'afirmativo', 'positivo', 'com certeza',
    'claro', 'beleza', 'blz', 'tá', 'ta', 'tá bom', 'ta bom', 'está bom', 'esta bom',
    'certo', 'correto', 'isso', 'isso mesmo', 'exato', 'perfeito', 'ótimo', 'otimo',
    'fechado', 'fechou', 'combinado', 'marca', 'marcar', 'agendar', 'agenda',
    'bora', 'vamos', 'demorou', 'verdade', 'perfeito', 'sim senhor', 'sim sim',
  ];

  static const List<String> _cancelWords = [
    'não', 'nao', 'cancela', 'cancelar', 'cancelado', 'errado', 'errada',
    'esquece', 'chega', 'basta', 'parar', 'nenhum', 'nada', 'deixa',
    'negativo', 'recusar', 'rejeito', 'não quero', 'nao quero', 'desiste', 'desistir',
    'tirar', 'remove', 'remover', 'apaga', 'apagar', 'dispensa', 'dispenso',
  ];

  static List<String> _normalizeTokens(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[.,!?;:]'), ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  static bool _matchesAny(String lower, List<String> words) {
    final tokens = _normalizeTokens(lower);
    return words.any((w) {
      final wl = w.toLowerCase();
      if (tokens.contains(wl)) return true;
      if (wl.contains(' ') && lower.contains(wl)) return true;
      return false;
    });
  }

  @override
  void didUpdateWidget(VoiceAssistant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSpeaking && !widget.isSpeaking) {
      if (_pending != null && !_isListening) {
        setState(() {
          _isListening = true;
        });
        _resumeListeningIfWaiting();
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
      return;
    }
    widget.stopSpeech();
    await Future.delayed(const Duration(milliseconds: 250));
    setState(() {
      _isListening = true;
      _handledSession = false;
      _transcript = '';
      _statusMessage = 'Microfone ligado e atento...';
    });

    if (!_speechReady) {
      _speechReady = await _speech.initialize(onStatus: _onSpeechStatus);
      if (!_speechReady && mounted) {
        setState(() {
          _isListening = false;
          _statusMessage = 'Microfone não disponível neste aparelho.';
        });
        return;
      }
    }

    await _speech.listen(
      onResult: _onResult,
      listenOptions: stt.SpeechListenOptions(
        localeId: 'pt_BR',
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  void _onResult(dynamic result) {
    if (!mounted) return;
    final text = result.recognizedWords.trim();
    setState(() {
      _transcript = text;
    });
    if (text.isEmpty) return;
    final lower = text.toLowerCase();

    // Ignore any partial/final result that belongs to an utterance already
    // handled in this listening session (e.g. the "sim" was confirmed on a
    // partial result and the matching finalResult arrives right after).
    if (_handledSession) return;

    // Stop the mic as soon as yes/no is understood — even on partial results —
    // so it never stays on after the word appears.
    if (_pending != null) {
      if (_matchesAny(lower, _cancelWords) || _matchesAny(lower, _confirmWords)) {
        _handledSession = true;
        _processVoiceInput(text);
        _stopListening();
        return;
      }
    }

    if (result.finalResult) {
      _handledSession = true;
      final handled = _processVoiceInput(text);
      if (handled) {
        _stopListening();
      } else if (_isListening) {
        _resumeListeningIfWaiting();
      }
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'done' || status == 'notListening' || status == 'error' || status == 'noSpeech') {
      if (_isListening && _pending != null && !widget.isSpeaking) {
        _resumeListeningIfWaiting();
      }
    }
  }

  Future<void> _resumeListeningIfWaiting() async {
    if (!_isListening || _pending == null || !_speechReady) return;
    if (widget.isSpeaking) return;
    if (_speech.isListening) return;
    _handledSession = false;
    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: stt.SpeechListenOptions(
          localeId: 'pt_BR',
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (_) {}
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }
  }

bool _processVoiceInput(String text) {
    final lower = text.toLowerCase().trim();

    if (_matchesAny(lower, _cancelWords)) {
      setState(() {
        _pending = null;
        _statusMessage = 'Compromisso cancelado.';
        _transcript = text;
      });
      widget.speakText('Cancelado. Nada foi agendado.');
      return true;
    }

    if (_pending != null) {
      if (_matchesAny(lower, _confirmWords)) {
        final cmd = _pending!;
        widget.onConfirmCommitment(cmd);
        final c = Commitment(
          id: 'pending',
          title: cmd.title,
          date: cmd.date,
          time: cmd.time,
          priority: cmd.priority,
          category: cmd.category,
          completed: false,
          recurrence: cmd.recurrence,
        );
        setState(() {
          _statusMessage = 'Você disse "$text". Compromisso "${cmd.title}" salvo com sucesso!';
          _pending = null;
          _transcript = text;
        });
        widget.speakText(Announcer.confirmation(c));
        _textController.clear();
        return true;
      }
    }

    final parsed = NaturalCommandParser().parse(text);
    setState(() {
      _pending = parsed;
      _statusMessage =
          'Você disse "$text". Compreendido: ${parsed.title} (${parsed.time}). Aguardando confirmação...';
      _transcript = text;
    });
    _stopListening();
    widget.speakText(
        'Vou agendar ${parsed.title} para ${DateFormatter.formatNaturalDate(parsed.date)} às ${parsed.time}. Diga sim para confirmar ou não para cancelar.');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.teal.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Text(
            '✦  ASSISTENTE DE VOZ INTELIGENTE',
            style: TextStyle(
                color: Colors.teal.shade100,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fale o compromisso e confirme com "Sim"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'O microfone ouve sua fala, aguarda o seu "Sim" ou "Não" e desliga automaticamente após salvar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.teal.shade100, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Big Microphone button
          GestureDetector(
            onTap: widget.isSpeaking && !_isListening ? widget.stopSpeech : _toggleListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening
                    ? Colors.red.shade400
                    : widget.isSpeaking
                        ? Colors.amber.shade400
                        : Colors.white,
                border: Border.all(
                  color: _isListening
                      ? Colors.red.shade200
                      : widget.isSpeaking
                          ? Colors.amber.shade200
                          : Colors.teal.shade200,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isListening
                        ? Colors.red.withValues(alpha: 0.5)
                        : widget.isSpeaking
                            ? Colors.amber.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _isListening
                  ? const Icon(Icons.mic_off, color: Colors.white, size: 48)
                  : widget.isSpeaking
                      ? const Icon(Icons.volume_up, color: Colors.white, size: 48)
                      : const Icon(Icons.mic, color: Color(0xFF0D9488), size: 48),
            ),
          ),
          const SizedBox(height: 10),
          if (_isListening)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.redAccent, size: 10),
                  SizedBox(width: 8),
                  Text('Microfone ativo... Fale agora. Vou mostrar o que você disse.',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (widget.isSpeaking && !_isListening)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up, color: Colors.amber, size: 14),
                  SizedBox(width: 8),
                  Text('Falando agora... Toque para Pausar a Voz e Falar.',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
if (_transcript.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                border: Border.all(color: Colors.teal.shade300),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🎤',
                          style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text('VOCÊ DISSE:',
                          style: TextStyle(color: Colors.teal.shade200, fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('"$_transcript"',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if (_pending != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      const Text('AGUARDANDO CONFIRMAÇÃO (Diga "Sim" ou "Não"):',
                          style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () {
                          _processVoiceInput('não');
                          _stopListening();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${_pending!.title}" às ${_pending!.time} (${_pending!.recurrence}).',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade400,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            _processVoiceInput('sim');
                            _stopListening();
                          },
                          child: const Text('Confirmar (Sim)', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          onPressed: () {
                            _processVoiceInput('não');
                            _stopListening();
                          },
                          child: const Text('Cancelar (Não)', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_statusMessage != null && _pending == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.shade500.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.teal.shade100, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(_statusMessage!,
                        style: TextStyle(color: Colors.teal.shade50, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Manual input backup
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: TextStyle(color: Colors.teal.shade900),
                  decoration: InputDecoration(
                    hintText: 'Ou digite aqui (Sim, Não, ou seu compromisso)...',
                    hintStyle: TextStyle(color: Colors.teal.shade100, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      _processVoiceInput(val.trim());
                      _stopListening();
                      _textController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onPressed: () {
                  if (_textController.text.trim().isNotEmpty) {
                    _processVoiceInput(_textController.text.trim());
                    _stopListening();
                    _textController.clear();
                  }
                },
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:audioplayers/audioplayers.dart';

/// Plays the alarm clock sound continuously (like a despertador) while the
/// alarm modal is open, and stops when the user dismisses it.
class AlarmPlayerService {
  static final AlarmPlayerService _instance = AlarmPlayerService._internal();
  factory AlarmPlayerService() => _instance;
  AlarmPlayerService._internal();

  AudioPlayer? _player;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// Android audio context routed to the ALARM stream: rings even in silent /
  /// Do Not Disturb mode (respecting only the alarm volume), and uses
  /// transient audio focus so other music is temporarily lowered.
  static final AudioContext _alarmAudioContext = AudioContext(
    android: AudioContextAndroid(
      usageType: AndroidUsageType.alarm,
      contentType: AndroidContentType.sonification,
      audioFocus: AndroidAudioFocus.gainTransient,
    ),
  );

  /// Starts the looping alarm sound.
  Future<void> start() async {
    if (_isPlaying) return;
    try {
      _player ??= AudioPlayer();
      // Route audio through the ALARM stream so the alarm sounds even when
      // the device is in silent mode (alarm volume settings still apply),
      // exactly like a native alarm clock app.
      await _player!.setAudioContext(_alarmAudioContext);
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(1.0);
      await _player!.play(AssetSource('sounds/alarm_sound.wav'));
      _isPlaying = true;
    } catch (_) {
      _isPlaying = false;
    }
  }

  /// Stops the looping alarm sound.
  Future<void> stop() async {
    _isPlaying = false;
    try {
      await _player?.stop();
    } catch (_) {}
  }
}

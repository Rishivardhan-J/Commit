import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class AmbientSound {
  final String id, label, emoji;
  final String? asset;
  const AmbientSound(this.id, this.label, this.emoji, this.asset);
}

const ambientSounds = [
  AmbientSound('none', 'Silence', '🔇', null),
  AmbientSound('brown', 'Brown noise', '🌊', 'sounds/brown.ogg'),
  AmbientSound('rain', 'Rain', '🌧️', 'sounds/rain.ogg'),
  AmbientSound('cafe', 'Café hum', '☕', 'sounds/cafe.ogg'),
];

/// Looping ambient sound for focus blocks with soft fades. Best effort: audio failures never
/// affect the timer.
class AmbientPlayer {
  AmbientPlayer._();
  static final instance = AmbientPlayer._();

  AudioPlayer? _player;
  String _current = 'none';
  Timer? _fade;

  Future<AudioPlayer> _ensure() async {
    final p = _player ??= AudioPlayer();
    await p.setReleaseMode(ReleaseMode.loop);
    await p.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none, // mix with whatever else is playing
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    ));
    return p;
  }

  /// Play [id] at [volume], fading in. 'none' behaves like [stop].
  Future<void> play(String id, double volume) async {
    final s = ambientSounds.firstWhere((a) => a.id == id, orElse: () => ambientSounds.first);
    if (s.asset == null) return stop();
    try {
      final p = await _ensure();
      if (_current != id) {
        await p.stop();
        await p.setVolume(0);
        await p.play(AssetSource(s.asset!));
        _current = id;
      } else if (p.state != PlayerState.playing) {
        await p.setVolume(0);
        await p.resume();
      }
      _fadeTo(p, volume);
    } catch (_) {}
  }

  Future<void> setVolume(double v) async {
    try {
      await _player?.setVolume(v);
    } catch (_) {}
  }

  Future<void> pause() async {
    final p = _player;
    if (p == null) return;
    _fadeTo(p, 0, then: () => p.pause());
  }

  Future<void> stop() async {
    final p = _player;
    _current = 'none';
    if (p == null) return;
    _fadeTo(p, 0, then: () => p.stop());
  }

  void _fadeTo(AudioPlayer p, double target, {Future<void> Function()? then}) {
    _fade?.cancel();
    var step = 0;
    const steps = 10;
    double from = p.volume;
    _fade = Timer.periodic(const Duration(milliseconds: 80), (t) async {
      step++;
      try {
        await p.setVolume(from + (target - from) * step / steps);
        if (step >= steps) {
          t.cancel();
          await then?.call();
        }
      } catch (_) {
        t.cancel();
      }
    });
  }
}

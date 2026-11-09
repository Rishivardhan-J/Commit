import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/day_key.dart';
import '../../data/models.dart';
import '../../data/app_store.dart';
import '../../services/notification_service.dart';
import 'ambient.dart';

enum FocusPhase { idle, focus, shortBreak, longBreak }

const shortBreakMin = 5;
const longBreakMin = 15;
const cycleLength = 4; // focus blocks before a long break

/// What happened when a phase ended, so the UI can celebrate exactly once.
class FocusEvent {
  final FocusPhase ended;
  final int minutes;
  final int xp;
  final bool cycleDone;
  final String? taskId;
  final String? sessionId; // the FocusSession written for a finished focus block
  const FocusEvent(this.ended, this.minutes, this.xp, this.cycleDone, this.taskId, [this.sessionId]);
}

class FocusState {
  final FocusPhase phase;
  final bool running;
  final DateTime? endsAt; // while running
  final Duration? paused; // remaining while paused
  final int focusMin; // chosen focus length
  final int phaseTotalSec; // length of the current phase (grows with +5 min)
  final int cycleIndex; // focus blocks finished in this cycle (0..3)
  final String? skill;
  final String? taskId;
  final String intention; // the "commit message" written before starting
  final int interruptions; // self-reported + app-switch count for the current block
  final int awaySec; // time spent outside the app during the current block
  final String sound; // ambient sound id ('none' | 'brown' | 'rain' | 'cafe')
  final double volume;
  final int dailyGoal; // minutes per day
  final FocusEvent? event; // last completed phase (not persisted)

  const FocusState({
    this.phase = FocusPhase.idle,
    this.running = false,
    this.endsAt,
    this.paused,
    this.focusMin = 25,
    this.phaseTotalSec = 25 * 60,
    this.cycleIndex = 0,
    this.skill,
    this.taskId,
    this.intention = '',
    this.interruptions = 0,
    this.awaySec = 0,
    this.sound = 'none',
    this.volume = 0.6,
    this.dailyGoal = 100,
    this.event,
  });

  bool get active => phase != FocusPhase.idle;
  bool get isBreak => phase == FocusPhase.shortBreak || phase == FocusPhase.longBreak;

  Duration remaining(DateTime now) {
    if (!active) return Duration(minutes: focusMin);
    if (!running) return paused ?? Duration(seconds: phaseTotalSec);
    final d = endsAt!.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  /// 0..1 through the current phase.
  double progress(DateTime now) {
    if (!active) return 0;
    final total = phaseTotalSec;
    return (1 - remaining(now).inMilliseconds / (total * 1000)).clamp(0.0, 1.0);
  }

  FocusState copyWith({
    FocusPhase? phase,
    bool? running,
    DateTime? endsAt,
    bool clearEndsAt = false,
    Duration? paused,
    bool clearPaused = false,
    int? focusMin,
    int? phaseTotalSec,
    int? cycleIndex,
    String? skill,
    String? taskId,
    bool clearTask = false,
    String? intention,
    int? interruptions,
    int? awaySec,
    String? sound,
    double? volume,
    int? dailyGoal,
    FocusEvent? event,
    bool clearEvent = false,
  }) =>
      FocusState(
        phase: phase ?? this.phase,
        running: running ?? this.running,
        endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
        paused: clearPaused ? null : (paused ?? this.paused),
        focusMin: focusMin ?? this.focusMin,
        phaseTotalSec: phaseTotalSec ?? this.phaseTotalSec,
        cycleIndex: cycleIndex ?? this.cycleIndex,
        skill: skill ?? this.skill,
        taskId: clearTask ? null : (taskId ?? this.taskId),
        intention: intention ?? this.intention,
        interruptions: interruptions ?? this.interruptions,
        awaySec: awaySec ?? this.awaySec,
        sound: sound ?? this.sound,
        volume: volume ?? this.volume,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        event: clearEvent ? null : (event ?? this.event),
      );

  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'running': running,
        'endsAt': endsAt?.toIso8601String(),
        'paused': paused?.inMilliseconds,
        'focusMin': focusMin,
        'total': phaseTotalSec,
        'cycle': cycleIndex,
        'skill': skill,
        'task': taskId,
        'intent': intention,
        'int': interruptions,
        'away': awaySec,
        'sound': sound,
        'vol': volume,
        'goal': dailyGoal,
      };

  factory FocusState.fromJson(Map<String, dynamic> j) => FocusState(
        phase: FocusPhase.values.byName(j['phase'] ?? 'idle'),
        running: j['running'] ?? false,
        endsAt: j['endsAt'] == null ? null : DateTime.parse(j['endsAt']),
        paused: j['paused'] == null ? null : Duration(milliseconds: j['paused']),
        focusMin: j['focusMin'] ?? 25,
        phaseTotalSec: j['total'] ?? 25 * 60,
        cycleIndex: j['cycle'] ?? 0,
        skill: j['skill'],
        taskId: j['task'],
        intention: j['intent'] ?? '',
        interruptions: j['int'] ?? 0,
        awaySec: j['away'] ?? 0,
        sound: j['sound'] ?? 'none',
        volume: (j['vol'] ?? 0.6).toDouble(),
        dailyGoal: j['goal'] ?? 100,
      );
}

const _key = 'commit_focus_v1';
const _uuid = Uuid();

final focusProvider = NotifierProvider<FocusController, FocusState>(FocusController.new);

/// Pomodoro engine. Time is always derived from a wall-clock `endsAt`, never a tick
/// counter, so it stays right across backgrounding and app restarts.
class FocusController extends Notifier<FocusState> {
  DateTime get _now => ref.read(clockProvider)();

  @override
  FocusState build() {
    final raw = ref.read(prefsProvider).getString(_key);
    var s = const FocusState();
    if (raw != null) {
      try {
        s = FocusState.fromJson(jsonDecode(raw));
      } catch (_) {}
    }
    return s;
  }

  String _soundKey = '';
  double _soundVol = -1;

  void _set(FocusState s) {
    state = s;
    ref.read(prefsProvider).setString(_key, jsonEncode(s.toJson()));
    _applySound(s);
  }

  /// Ambient sound follows the timer: plays while a focus block runs, fades out otherwise.
  void _applySound(FocusState s) {
    final key = '${s.phase.name}|${s.running}|${s.sound}';
    if (key != _soundKey) {
      _soundKey = key;
      final amb = AmbientPlayer.instance;
      if (s.sound != 'none' && s.phase == FocusPhase.focus && s.running) {
        amb.play(s.sound, s.volume);
      } else if (s.sound != 'none' && s.phase == FocusPhase.focus) {
        amb.pause();
      } else {
        amb.stop();
      }
    } else if (s.volume != _soundVol && s.running) {
      AmbientPlayer.instance.setVolume(s.volume);
    }
    _soundVol = s.volume;
  }

  // ---- setup (only while idle) ----
  void setLength(int minutes) {
    if (state.active) return;
    final m = minutes.clamp(5, 120);
    _set(state.copyWith(focusMin: m, phaseTotalSec: m * 60));
  }

  void setIntention(String v) => _set(state.copyWith(intention: v));
  void setSound(String id) => _set(state.copyWith(sound: id));
  void setVolume(double v) => _set(state.copyWith(volume: v.clamp(0.0, 1.0)));
  void setDailyGoal(int m) => _set(state.copyWith(dailyGoal: m.clamp(10, 600)));
  void addInterruption() {
    if (state.phase == FocusPhase.focus) _set(state.copyWith(interruptions: state.interruptions + 1));
  }

  DateTime? _leftAt;

  /// App went to the background mid-block: remember when, so the return can report time away.
  void leftApp() {
    if (state.phase == FocusPhase.focus && state.running) _leftAt = _now;
  }

  /// Back in the app. Returns how long we were away (null if it wasn't a block in progress).
  Duration? returnedToApp() {
    final at = _leftAt;
    _leftAt = null;
    if (at == null || state.phase != FocusPhase.focus) return null;
    final away = _now.difference(at);
    if (away.inSeconds < 10) return null;
    _set(state.copyWith(interruptions: state.interruptions + 1, awaySec: state.awaySec + away.inSeconds));
    return away;
  }

  void setSkill(String skill) => _set(state.copyWith(skill: skill));
  void setTask(String? id, {String? skill}) =>
      _set(id == null ? state.copyWith(clearTask: true) : state.copyWith(taskId: id, skill: skill));

  // ---- running ----
  void start() {
    if (state.running) return;
    _startPhase(FocusPhase.focus, state.focusMin * 60);
  }

  void _startPhase(FocusPhase phase, int seconds, {int? cycle}) {
    final end = _now.add(Duration(seconds: seconds));
    _set(state.copyWith(
      phase: phase,
      running: true,
      endsAt: end,
      clearPaused: true,
      phaseTotalSec: seconds,
      cycleIndex: cycle,
      interruptions: phase == FocusPhase.focus ? 0 : null,
      awaySec: phase == FocusPhase.focus ? 0 : null,
      clearEvent: true,
    ));
    _syncNotification();
  }

  void pause() {
    if (!state.running) return;
    final left = state.remaining(_now);
    _set(state.copyWith(running: false, paused: left, clearEndsAt: true));
    NotificationService.instance.cancelFocus();
  }

  void resume() {
    if (!state.active || state.running) return;
    _set(state.copyWith(running: true, endsAt: _now.add(state.paused ?? Duration.zero), clearPaused: true));
    _syncNotification();
  }

  void addFive() {
    if (!state.active) return;
    if (state.running) {
      _set(state.copyWith(endsAt: state.endsAt!.add(const Duration(minutes: 5)), phaseTotalSec: state.phaseTotalSec + 300));
      _syncNotification();
    } else {
      _set(state.copyWith(paused: (state.paused ?? Duration.zero) + const Duration(minutes: 5), phaseTotalSec: state.phaseTotalSec + 300));
    }
  }

  /// Abandon the current phase. A focus block still logs the whole minutes actually focused.
  FocusEvent? stop() {
    FocusEvent? ev;
    if (state.phase == FocusPhase.focus) {
      final spentSec = state.phaseTotalSec - state.remaining(_now).inSeconds;
      final mins = spentSec ~/ 60;
      if (mins >= 1) ev = _logFocus(mins, cycleDone: false);
    }
    _set(state.copyWith(
      phase: FocusPhase.idle,
      running: false,
      clearEndsAt: true,
      clearPaused: true,
      phaseTotalSec: state.focusMin * 60,
      clearEvent: true,
    ));
    NotificationService.instance.cancelFocus();
    return ev;
  }

  /// After a break: skip straight back to idle, ready for the next block.
  void skipBreak() {
    if (!state.isBreak) return;
    _toIdle();
  }

  void _toIdle() {
    _set(state.copyWith(phase: FocusPhase.idle, running: false, clearEndsAt: true, clearPaused: true, phaseTotalSec: state.focusMin * 60));
    NotificationService.instance.cancelFocus();
  }

  FocusEvent _logFocus(int mins, {required bool cycleDone}) {
    final skill = state.skill ?? 'General';
    final app = ref.read(appProvider.notifier);
    final xp = app.logFocus(skill, mins);
    final id = _uuid.v4();
    app.addFocusSession(FocusSession(
      id: id,
      day: dayKey(_now),
      skill: skill,
      minutes: mins,
      message: state.intention.trim(),
      interruptions: state.interruptions,
      awaySec: state.awaySec,
      taskId: state.taskId,
    ));
    return FocusEvent(FocusPhase.focus, mins, xp, cycleDone, state.taskId, id);
  }

  /// Called by the UI every frame/second and on app resume. Completes the phase when due.
  void evaluate() {
    if (!state.running || state.endsAt == null) return;
    if (_now.isBefore(state.endsAt!)) return;
    if (state.phase == FocusPhase.focus) {
      final mins = (state.phaseTotalSec / 60).round();
      final doneCount = state.cycleIndex + 1;
      final cycleDone = doneCount >= cycleLength;
      final ev = _logFocus(mins, cycleDone: cycleDone);
      final next = cycleDone ? FocusPhase.longBreak : FocusPhase.shortBreak;
      final secs = (cycleDone ? longBreakMin : shortBreakMin) * 60;
      _startPhase(next, secs, cycle: cycleDone ? 0 : doneCount);
      _set(state.copyWith(event: ev));
    } else {
      final ev = FocusEvent(state.phase, (state.phaseTotalSec / 60).round(), 0, false, null);
      _toIdle();
      _set(state.copyWith(event: ev));
    }
  }

  void clearEvent() => _set(state.copyWith(clearEvent: true));

  void _syncNotification() {
    final s = state;
    if (!s.running || s.endsAt == null) return;
    final svc = NotificationService.instance;
    switch (s.phase) {
      case FocusPhase.focus:
        svc.showFocusRunning(title: 'Focus', body: s.skill == null ? 'Stay with it' : 'Working on ${s.skill}', endsAt: s.endsAt!);
      case FocusPhase.shortBreak:
        svc.showFocusRunning(title: 'Short break', body: 'Stretch, water, eyes off the screen', endsAt: s.endsAt!);
      case FocusPhase.longBreak:
        svc.showFocusRunning(title: 'Long break', body: 'You finished a full cycle — recharge', endsAt: s.endsAt!);
      case FocusPhase.idle:
        break;
    }
  }
}

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:xstream_player/src/configuration/better_player_buffering_configuration.dart';
import 'package:xstream_player/src/video_player/video_player_platform_interface.dart';

// ─── hls.js interop ──────────────────────────────────────────────────────────

/// Typed wrapper over a hls.js instance.
extension type _HlsJs(JSObject _) implements JSObject {
  external void loadSource(String src);
  external void attachMedia(JSObject media);
  external void destroy();
  external void on(String event, JSFunction callback);
  @JS('Events')
  external JSObject get hlsEvents;
}

/// Typed wrapper over hls.js Events object to read event name constants.
extension type _HlsEvents(JSObject _) implements JSObject {
  @JS('ERROR')
  external String get errorEvent;
  @JS('MANIFEST_PARSED')
  external String get manifestParsedEvent;
}

/// Data object passed to hls.js error callbacks.
extension type _HlsErrorData(JSObject _) implements JSObject {
  external bool get fatal;
  @JS('type')
  external String get errorType;
  external String get details;
}

// ─── Platform implementation ─────────────────────────────────────────────────

/// Web implementation of [VideoPlayerPlatform] using the HTML5 <video> element.
/// HLS streams use hls.js in Chrome/Firefox; Safari plays HLS natively.
class WebVideoPlayer extends VideoPlayerPlatform {
  final Map<int, _WebPlayerState> _players = {};
  int _textureIdCounter = 0;

  @override
  Future<void> init() async {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
    _textureIdCounter = 0;
  }

  @override
  Future<int?> create({BetterPlayerBufferingConfiguration? bufferingConfiguration}) async {
    final id = _textureIdCounter++;
    _players[id] = _WebPlayerState(id);
    return id;
  }

  @override
  Future<void> dispose(int? textureId) async {
    final player = _players.remove(textureId);
    player?.dispose();
  }

  @override
  Future<void> setDataSource(int? textureId, DataSource dataSource) async {
    final player = _players[textureId];
    if (player == null) {
      return;
    }
    await player.setDataSource(dataSource);
  }

  @override
  Stream<VideoEvent> videoEventsFor(int? textureId) {
    final player = _players[textureId];
    if (player == null) {
      return const Stream.empty();
    }
    return player.eventStream;
  }

  @override
  Future<void> play(int? textureId) async => _players[textureId]?.play();

  @override
  Future<void> pause(int? textureId) async => _players[textureId]?.pause();

  @override
  Future<void> setVolume(int? textureId, double volume) async =>
      _players[textureId]?.setVolume(volume);

  @override
  Future<void> setSpeed(int? textureId, double speed) async =>
      _players[textureId]?.setSpeed(speed);

  @override
  Future<void> setLooping(int? textureId, bool looping) async =>
      _players[textureId]?.setLooping(looping);

  @override
  Future<void> seekTo(int? textureId, Duration? position) async {
    if (position == null) {
      return;
    }
    _players[textureId]?.seekTo(position);
  }

  @override
  Future<Duration> getPosition(int? textureId) async =>
      _players[textureId]?.getPosition() ?? Duration.zero;

  @override
  Future<DateTime?> getAbsolutePosition(int? textureId) async => null;

  @override
  Future<void> setTrackParameters(int? textureId, int? width, int? height, int? bitrate) async {}

  @override
  Future<void> setTrackConstraint(int? textureId, int? width, int? height, int? bitrate) async {}

  @override
  Future<void> enablePictureInPicture(int? textureId, double? top, double? left, double? width, double? height) async {}

  @override
  Future<void> disablePictureInPicture(int? textureId) async {}

  @override
  Future<bool?> isPictureInPictureEnabled(int? textureId) async => false;

  @override
  Future<void> setAudioTrack(int? textureId, String? name, int? index) async {}

  @override
  Future<void> setMixWithOthers(int? textureId, bool mixWithOthers) async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> preCache(DataSource dataSource, int preCacheSize) async {}

  @override
  Future<void> stopPreCache(String url, String? cacheKey) async {}

  @override
  Widget buildView(int? textureId) =>
      HtmlElementView(viewType: 'xstream-player-$textureId');
}

// ─── Per-player state ─────────────────────────────────────────────────────────

class _WebPlayerState {
  _WebPlayerState(this.id) {
    _videoElement = html.VideoElement()
      ..autoplay = false
      ..controls = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.objectFit = 'contain'
      ..setAttribute('crossorigin', 'anonymous');

    ui_web.platformViewRegistry.registerViewFactory(
      'xstream-player-$id',
      (_) => _videoElement,
    );

    _setupEventListeners();
  }

  final int id;
  late final html.VideoElement _videoElement;
  final StreamController<VideoEvent> _eventController = StreamController.broadcast();
  String? _currentKey;
  _HlsJs? _hls;

  Stream<VideoEvent> get eventStream => _eventController.stream;

  // ─── HLS helpers ─────────────────────────────────────────────────────────

  static bool _isHlsUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('m3u8');
  }

  bool _canPlayHlsNatively() {
    final t = _videoElement.canPlayType('application/vnd.apple.mpegurl');
    return t == 'maybe' || t == 'probably';
  }

  /// True when window.Hls is defined — i.e. hls.js script is loaded.
  static bool get _hlsAvailable {
    final win = html.window as JSObject;
    return win.has('Hls');
  }

  /// Creates a hls.js instance from the global Hls constructor.
  static _HlsJs _createHlsInstance() {
    final win = html.window as JSObject;
    final ctor = win['Hls']! as JSFunction;
    final config = {
      'enableWorker': true,
      'lowLatencyMode': false,
      'manifestLoadingTimeOut': 20000,
      'manifestLoadingMaxRetry': 3,
      'fragLoadingTimeOut': 20000,
    }.jsify()! as JSObject;
    return _HlsJs(ctor.callAsConstructor<JSObject>(config));
  }

  // ─── Event listeners ─────────────────────────────────────────────────────

  void _setupEventListeners() {
    _videoElement.onLoadedMetadata.listen((_) {
      final rawDuration = _videoElement.duration;
      final durationMs = rawDuration.isFinite && !rawDuration.isNaN
          ? (rawDuration * 1000).round()
          : 0;
      _emit(VideoEvent(
        eventType: VideoEventType.initialized,
        key: _currentKey,
        duration: Duration(milliseconds: durationMs),
        size: Size(_videoElement.videoWidth.toDouble(), _videoElement.videoHeight.toDouble()),
      ));
    });

    _videoElement.onEnded.listen((_) =>
        _emit(VideoEvent(eventType: VideoEventType.completed, key: _currentKey)));

    // Emit isPlayingChanged only — do NOT emit VideoEventType.play/pause back
    // to the controller, because that would cause an infinite loop:
    //   platform.play() → onPlay → emit play → controller.play() → platform.play() → …
    _videoElement.onPlay.listen((_) {
      _emit(VideoEvent(eventType: VideoEventType.isPlayingChanged, key: _currentKey, isPlaying: true));
    });

    _videoElement.onPause.listen((_) {
      _emit(VideoEvent(eventType: VideoEventType.isPlayingChanged, key: _currentKey, isPlaying: false));
    });

    _videoElement.onWaiting.listen((_) =>
        _emit(VideoEvent(eventType: VideoEventType.bufferingStart, key: _currentKey)));

    _videoElement.onCanPlay.listen((_) =>
        _emit(VideoEvent(eventType: VideoEventType.bufferingEnd, key: _currentKey)));

    _videoElement.onTimeUpdate.listen((_) {
      final buf = _videoElement.buffered;
      final ranges = <DurationRange>[];
      for (var i = 0; i < buf.length; i++) {
        ranges.add(DurationRange(
          Duration(milliseconds: (buf.start(i) * 1000).round()),
          Duration(milliseconds: (buf.end(i) * 1000).round()),
        ));
      }
      _emit(VideoEvent(eventType: VideoEventType.bufferingUpdate, key: _currentKey, buffered: ranges));
    });

    // NOTE: We intentionally do NOT forward onSeeked as VideoEventType.seek.
    // The controller (video_player.dart) handles seek events by calling seekTo()
    // again, which would create an infinite feedback loop on web:
    //   controller.seekTo() → currentTime = X → onseeked → emit seek →
    //   controller.seekTo(X) → currentTime = X → onseeked → …
    // On native, seek events come from external sources (media session / notifications)
    // and this feedback is intentional. On web we control seeking directly.

    // Video element errors (also catches hls.js fatal errors via MSE)
    _videoElement.onError.listen((_) =>
        _emit(VideoEvent(eventType: VideoEventType.bufferingEnd, key: _currentKey)));
  }

  void _emit(VideoEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  // ─── Data source ─────────────────────────────────────────────────────────

  Future<void> setDataSource(DataSource dataSource) async {
    _currentKey = dataSource.key;
    final url = dataSource.uri ?? '';

    _destroyHls();

    if (_isHlsUrl(url) && !_canPlayHlsNatively()) {
      if (_hlsAvailable) {
        _loadWithHlsJs(url);
        return;
      }
      // ignore: avoid_print
      print(
        '[xstream_player] HLS URL detected but hls.js is not loaded. '
        'Add <script src="https://cdn.jsdelivr.net/npm/hls.js@latest/dist/hls.min.js"></script> '
        'to your web/index.html.',
      );
    }

    _videoElement
      ..src = url
      ..load();
  }

  void _loadWithHlsJs(String url) {
    _hls = _createHlsInstance();
    _hls!.loadSource(url);
    _hls!.attachMedia(_videoElement as JSObject);
    _attachHlsErrorHandler();
  }

  void _attachHlsErrorHandler() {
    if (_hls == null) {
      return;
    }
    final events = _HlsEvents(_hls!.hlsEvents);

    // Keep a reference to current state for the callback closure
    final key = _currentKey;
    void onError(String event, JSObject data) {
      final err = _HlsErrorData(data);
      if (err.fatal) {
        // ignore: avoid_print
        print('[xstream_player] hls.js fatal error: ${err.errorType} / ${err.details}');
        _emit(VideoEvent(eventType: VideoEventType.bufferingEnd, key: key));
      }
    }

    _hls!.on(events.errorEvent, onError.toJS);
  }

  void _destroyHls() {
    if (_hls != null) {
      try {
        _hls!.destroy();
      } catch (_) {}
      _hls = null;
    }
  }

  // ─── Playback controls ────────────────────────────────────────────────────

  Future<void> play() => _videoElement.play();

  void pause() => _videoElement.pause();

  void setVolume(double volume) {
    _videoElement.volume = volume;
    _videoElement.muted = volume == 0;
  }

  void setSpeed(double speed) => _videoElement.playbackRate = speed;

  void setLooping(bool looping) => _videoElement.loop = looping;

  void seekTo(Duration position) =>
      _videoElement.currentTime = position.inMilliseconds / 1000.0;

  Duration getPosition() =>
      Duration(milliseconds: (_videoElement.currentTime * 1000).round());

  void dispose() {
    _destroyHls();
    _videoElement
      ..pause()
      ..src = '';
    if (!_eventController.isClosed) {
      _eventController.close();
    }
  }
}

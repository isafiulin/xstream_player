// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:xstream_player/src/configuration/better_player_buffering_configuration.dart';
import 'package:xstream_player/src/video_player/video_player_platform_interface.dart';

/// Web implementation of [VideoPlayerPlatform] using the HTML5 <video> element.
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
    final state = _WebPlayerState(id);
    _players[id] = state;
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
  Future<void> play(int? textureId) async {
    await _players[textureId]?.play();
  }

  @override
  Future<void> pause(int? textureId) async {
    _players[textureId]?.pause();
  }

  @override
  Future<void> setVolume(int? textureId, double volume) async {
    _players[textureId]?.setVolume(volume);
  }

  @override
  Future<void> setSpeed(int? textureId, double speed) async {
    _players[textureId]?.setSpeed(speed);
  }

  @override
  Future<void> setLooping(int? textureId, bool looping) async {
    _players[textureId]?.setLooping(looping);
  }

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
  Future<void> enablePictureInPicture(
    int? textureId,
    double? top,
    double? left,
    double? width,
    double? height,
  ) async {}

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

/// Internal state for a single web video player instance.
class _WebPlayerState {
  _WebPlayerState(this.id) {
    _videoElement = html.VideoElement()
      ..autoplay = false
      ..controls = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.objectFit = 'contain';

    ui_web.platformViewRegistry.registerViewFactory(
      'xstream-player-$id',
      (_) => _videoElement,
    );

    _setupEventListeners();
  }

  final int id;
  late final html.VideoElement _videoElement;
  final StreamController<VideoEvent> _eventController =
      StreamController.broadcast();
  String? _currentKey;

  Stream<VideoEvent> get eventStream => _eventController.stream;

  void _setupEventListeners() {
    _videoElement.onLoadedMetadata.listen((_) {
      final rawDuration = _videoElement.duration;
      final durationMs =
          (rawDuration.isFinite && !rawDuration.isNaN)
              ? (rawDuration * 1000).round()
              : 0;
      final width = _videoElement.videoWidth.toDouble();
      final height = _videoElement.videoHeight.toDouble();

      _eventController.add(VideoEvent(
        eventType: VideoEventType.initialized,
        key: _currentKey,
        duration: Duration(milliseconds: durationMs),
        size: Size(width, height),
      ));
    });

    _videoElement.onEnded.listen((_) {
      _eventController.add(VideoEvent(
        eventType: VideoEventType.completed,
        key: _currentKey,
      ));
    });

    _videoElement.onPlay.listen((_) {
      _eventController
        ..add(VideoEvent(
          eventType: VideoEventType.isPlayingChanged,
          key: _currentKey,
          isPlaying: true,
        ))
        ..add(VideoEvent(
          eventType: VideoEventType.play,
          key: _currentKey,
          isPlaying: true,
        ));
    });

    _videoElement.onPause.listen((_) {
      _eventController
        ..add(VideoEvent(
          eventType: VideoEventType.isPlayingChanged,
          key: _currentKey,
          isPlaying: false,
        ))
        ..add(VideoEvent(
          eventType: VideoEventType.pause,
          key: _currentKey,
          isPlaying: false,
        ));
    });

    _videoElement.onWaiting.listen((_) {
      _eventController.add(VideoEvent(
        eventType: VideoEventType.bufferingStart,
        key: _currentKey,
      ));
    });

    _videoElement.onCanPlay.listen((_) {
      _eventController.add(VideoEvent(
        eventType: VideoEventType.bufferingEnd,
        key: _currentKey,
      ));
    });

    _videoElement.onTimeUpdate.listen((_) {
      final bufferedRanges = _videoElement.buffered;
      final ranges = <DurationRange>[];
      for (var i = 0; i < bufferedRanges.length; i++) {
        ranges.add(DurationRange(
          Duration(milliseconds: (bufferedRanges.start(i) * 1000).round()),
          Duration(milliseconds: (bufferedRanges.end(i) * 1000).round()),
        ));
      }
      _eventController.add(VideoEvent(
        eventType: VideoEventType.bufferingUpdate,
        key: _currentKey,
        buffered: ranges,
      ));
    });

    _videoElement.onSeeked.listen((_) {
      _eventController.add(VideoEvent(
        eventType: VideoEventType.seek,
        key: _currentKey,
        position: Duration(
          milliseconds: (_videoElement.currentTime * 1000).round(),
        ),
      ));
    });

    _videoElement.onError.listen((_) {
      _eventController.add(VideoEvent(
        eventType: VideoEventType.bufferingEnd,
        key: _currentKey,
      ));
    });
  }

  Future<void> setDataSource(DataSource dataSource) async {
    _currentKey = dataSource.key;
    _videoElement
      ..src = dataSource.uri ?? ''
      ..load();
  }

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
    _videoElement
      ..pause()
      ..src = '';
    if (!_eventController.isClosed) {
      _eventController.close();
    }
  }
}

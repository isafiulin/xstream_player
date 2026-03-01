import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:xstream_player/src/configuration/better_player_controller_event.dart';
import 'package:xstream_player/src/controls/better_player_cupertino_controls.dart';
import 'package:xstream_player/src/controls/better_player_material_controls.dart';
import 'package:xstream_player/src/core/better_player_utils.dart';
import 'package:xstream_player/src/subtitles/better_player_subtitles_drawer.dart';
import 'package:xstream_player/src/video_player/video_player.dart';
import 'package:xstream_player/xstream_player.dart';

class BetterPlayerWithControls extends StatefulWidget {
  const BetterPlayerWithControls({super.key, this.controller});

  final BetterPlayerController? controller;

  @override
  State<BetterPlayerWithControls> createState() => _BetterPlayerWithControlsState();
}

class _BetterPlayerWithControlsState extends State<BetterPlayerWithControls> {
  BetterPlayerSubtitlesConfiguration get subtitlesConfiguration =>
      widget.controller!.betterPlayerConfiguration.subtitlesConfiguration;

  BetterPlayerControlsConfiguration get controlsConfiguration => widget.controller!.betterPlayerControlsConfiguration;

  final StreamController<bool> playerVisibilityStreamController = StreamController();

  bool _initialized = false;

  StreamSubscription<BetterPlayerControllerEvent>? _controllerEventSubscription;

  @override
  void initState() {
    playerVisibilityStreamController.add(true);
    _controllerEventSubscription = widget.controller!.controllerEventStream.listen(_onControllerChanged);
    super.initState();
  }

  @override
  void didUpdateWidget(BetterPlayerWithControls oldWidget) {
    if (oldWidget.controller != widget.controller) {
      _controllerEventSubscription?.cancel();
      _controllerEventSubscription = widget.controller!.controllerEventStream.listen(_onControllerChanged);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    playerVisibilityStreamController.close();
    _controllerEventSubscription?.cancel();
    super.dispose();
  }

  void _onControllerChanged(BetterPlayerControllerEvent event) {
    setState(() {
      if (!_initialized) {
        _initialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final BetterPlayerController betterPlayerController = BetterPlayerController.of(context);

    double? aspectRatio;
    if (betterPlayerController.isFullScreen) {
      if (betterPlayerController.betterPlayerConfiguration.autoDetectFullscreenDeviceOrientation ||
          betterPlayerController.betterPlayerConfiguration.autoDetectFullscreenAspectRatio) {
        aspectRatio = betterPlayerController.videoPlayerController?.value.aspectRatio ?? 1.0;
      } else {
        aspectRatio =
            betterPlayerController.betterPlayerConfiguration.fullScreenAspectRatio ??
            BetterPlayerUtils.calculateAspectRatio(context);
      }
    } else {
      aspectRatio = betterPlayerController.getAspectRatio();
    }

    aspectRatio ??= 16 / 9;
    if (aspectRatio.isNaN || aspectRatio.isInfinite || aspectRatio <= 0) {
      aspectRatio = 16 / 9;
    }
    final innerContainer = Container(
      width: double.infinity,
      color: betterPlayerController.betterPlayerConfiguration.controlsConfiguration.backgroundColor,
      child: AspectRatio(aspectRatio: aspectRatio, child: _buildPlayerWithControls(betterPlayerController, context)),
    );

    if (betterPlayerController.betterPlayerConfiguration.expandToFill) {
      return Center(child: innerContainer);
    } else {
      return innerContainer;
    }
  }

  Container _buildPlayerWithControls(BetterPlayerController betterPlayerController, BuildContext context) {
    final configuration = betterPlayerController.betterPlayerConfiguration;
    var rotation = configuration.rotation;

    if (!(rotation <= 360 && rotation % 90 == 0)) {
      BetterPlayerUtils.log('Invalid rotation provided. Using rotation = 0');
      rotation = 0;
    }
    if (betterPlayerController.betterPlayerDataSource == null) {
      return Container();
    }
    _initialized = true;

    final bool placeholderOnTop = betterPlayerController.betterPlayerConfiguration.placeholderOnTop;
    // ignore: avoid_unnecessary_containers
    return Container(
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          if (placeholderOnTop) _buildPlaceholder(betterPlayerController),
          Transform.rotate(
            angle: rotation * pi / 180,
            child: _BetterPlayerVideoFitWidget(betterPlayerController, betterPlayerController.getFit()),
          ),
          betterPlayerController.betterPlayerConfiguration.overlay ?? Container(),
          BetterPlayerSubtitlesDrawer(
            betterPlayerController: betterPlayerController,
            betterPlayerSubtitlesConfiguration: subtitlesConfiguration,
            subtitles: betterPlayerController.subtitlesLines,
            playerVisibilityStream: playerVisibilityStreamController.stream,
          ),
          if (!placeholderOnTop) _buildPlaceholder(betterPlayerController),
          _buildControls(context, betterPlayerController),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BetterPlayerController betterPlayerController) =>
      betterPlayerController.betterPlayerDataSource!.placeholder ??
      betterPlayerController.betterPlayerConfiguration.placeholder ??
      Container();

  Widget _buildControls(BuildContext context, BetterPlayerController betterPlayerController) {
    if (controlsConfiguration.showControls) {
      BetterPlayerTheme? playerTheme = controlsConfiguration.playerTheme;
      if (playerTheme == null) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          playerTheme = BetterPlayerTheme.material;
        } else {
          playerTheme = BetterPlayerTheme.cupertino;
        }
      }

      if (controlsConfiguration.customControlsBuilder != null && playerTheme == BetterPlayerTheme.custom) {
        return controlsConfiguration.customControlsBuilder!(
          betterPlayerController,
          onControlsVisibilityChanged,
          controlsConfiguration,
        );
      } else if (playerTheme == BetterPlayerTheme.material) {
        return _buildMaterialControl();
      } else if (playerTheme == BetterPlayerTheme.cupertino) {
        return _buildCupertinoControl();
      }
    }

    return const SizedBox();
  }

  Widget _buildMaterialControl() => BetterPlayerMaterialControls(
    onControlsVisibilityChanged: onControlsVisibilityChanged,
    controlsConfiguration: controlsConfiguration,
  );

  Widget _buildCupertinoControl() => BetterPlayerCupertinoControls(
    onControlsVisibilityChanged: onControlsVisibilityChanged,
    controlsConfiguration: controlsConfiguration,
  );

  void onControlsVisibilityChanged(bool state) {
    playerVisibilityStreamController.add(state);
  }
}

///Widget used to set the proper box fit of the video. Default fit is 'fill'.
class _BetterPlayerVideoFitWidget extends StatefulWidget {
  const _BetterPlayerVideoFitWidget(this.betterPlayerController, this.boxFit);

  final BetterPlayerController betterPlayerController;
  final BoxFit boxFit;

  @override
  _BetterPlayerVideoFitWidgetState createState() => _BetterPlayerVideoFitWidgetState();
}

class _BetterPlayerVideoFitWidgetState extends State<_BetterPlayerVideoFitWidget> {
  VideoPlayerController? get controller => widget.betterPlayerController.videoPlayerController;

  bool _initialized = false;

  VoidCallback? _initializedListener;

  bool _started = false;

  StreamSubscription<BetterPlayerControllerEvent>? _controllerEventSubscription;

  // On web, we use a key to force VideoPlayer to recreate its HtmlElementView
  // after exiting fullscreen. When fullscreen opens, a second HtmlElementView
  // is created with the same viewType, which moves the <video> DOM element to
  // the fullscreen slot. When fullscreen closes, the element is detached from
  // the DOM. Changing this key disposes the stale HtmlElementView and creates
  // a fresh one, re-embedding the <video> element back into the normal slot.
  Key _playerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (!widget.betterPlayerController.betterPlayerConfiguration.showPlaceholderUntilPlay) {
      _started = true;
    } else {
      _started = widget.betterPlayerController.hasCurrentDataSourceStarted;
    }

    _initialize();
  }

  @override
  void didUpdateWidget(_BetterPlayerVideoFitWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.betterPlayerController.videoPlayerController != controller) {
      if (_initializedListener != null) {
        oldWidget.betterPlayerController.videoPlayerController!.removeListener(_initializedListener!);
      }
      _initialized = false;
      _initialize();
    }
  }

  void _initialize() {
    if (controller?.value.initialized == false) {
      _initializedListener = () {
        if (!mounted) {
          return;
        }

        if (_initialized != controller!.value.initialized) {
          _initialized = controller!.value.initialized;
          setState(() {});
        }
      };
      controller!.addListener(_initializedListener!);
    } else {
      _initialized = true;
    }

    _controllerEventSubscription = widget.betterPlayerController.controllerEventStream.listen((event) {
      if (event == BetterPlayerControllerEvent.play) {
        if (!_started) {
          setState(() {
            _started = widget.betterPlayerController.hasCurrentDataSourceStarted;
          });
        }
      }
      if (event == BetterPlayerControllerEvent.setupDataSource) {
        setState(() {
          _started = false;
        });
      }
      // On web, force VideoPlayer to recreate its HtmlElementView after
      // returning from fullscreen so the <video> element is re-embedded.
      if (kIsWeb && event == BetterPlayerControllerEvent.hideFullscreen) {
        setState(() {
          _playerKey = UniqueKey();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized && _started) {
      // iOS platform views (UiKitView) don't play well with Clip/Transform/FittedBox.
      // Render the platform view directly to avoid black screen.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return SizedBox.expand(child: VideoPlayer(controller, key: _playerKey));
      }
      return Center(
        child: ClipRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: widget.boxFit,
              child: SizedBox(
                width: max(1, controller!.value.size?.width ?? 1.0),
                height: max(1, controller!.value.size?.height ?? 1.0),
                child: VideoPlayer(controller, key: _playerKey),
              ),
            ),
          ),
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  @override
  void dispose() {
    if (_initializedListener != null) {
      widget.betterPlayerController.videoPlayerController!.removeListener(_initializedListener!);
    }
    _controllerEventSubscription?.cancel();
    super.dispose();
  }
}

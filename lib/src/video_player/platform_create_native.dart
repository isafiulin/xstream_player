import 'package:xstream_player/src/video_player/method_channel_video_player.dart';
import 'package:xstream_player/src/video_player/video_player_platform_interface.dart';

/// Returns the default [VideoPlayerPlatform] for native (Android/iOS) targets.
VideoPlayerPlatform createVideoPlayerPlatform() =>
    MethodChannelVideoPlayer() as VideoPlayerPlatform;

import 'package:xstream_player/src/video_player/video_player_platform_interface.dart';
import 'package:xstream_player/src/video_player/web_video_player.dart';

/// Returns the default [VideoPlayerPlatform] for web targets.
VideoPlayerPlatform createVideoPlayerPlatform() => WebVideoPlayer();

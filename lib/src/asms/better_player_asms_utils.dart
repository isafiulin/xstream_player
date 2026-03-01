import 'package:http/http.dart' as http;
import 'package:xstream_player/src/asms/better_player_asms_data_holder.dart';
import 'package:xstream_player/src/clearkey/better_player_clearkey_utils.dart';
import 'package:xstream_player/src/core/better_player_utils.dart';
import 'package:xstream_player/src/hls/better_player_hls_utils.dart';

///Base helper class for ASMS parsing.
class BetterPlayerAsmsUtils {
  const BetterPlayerAsmsUtils._();

  static const String _hlsExtension = 'm3u8';
  static const String _dashExtension = 'mpd';

  ///Check if given url is HLS / DASH-type data source.
  static bool isDataSourceAsms(String url) => isDataSourceHls(url) || isDataSourceDash(url);

  ///Check if given url is HLS-type data source.
  static bool isDataSourceHls(String url) => url.contains(_hlsExtension);

  ///Check if given url is DASH-type data source.
  static bool isDataSourceDash(String url) => url.contains(_dashExtension);

  ///Parse playlist based on type of stream.
  static Future<BetterPlayerAsmsDataHolder> parse(String data, String masterPlaylistUrl) async =>
      BetterPlayerHlsUtils.parse(data, masterPlaylistUrl);

  ///Request data from given uri along with headers. May return null if resource
  ///is not available or on error.
  static Future<String?> getDataFromUrl(String url, [Map<String, String?>? headers, String? sig]) async {
    try {
      var uri = Uri.parse(url);
      if (sig != null) {
        final lastSegment = uri.pathSegments.last;
        final computedSig = BetterPlayerClearKeyUtils.computeHmacSha256Base64(sig, lastSegment);
        uri = uri.replace(queryParameters: {'sig': computedSig});
      }

      final resolvedHeaders = headers != null
          ? Map.fromEntries(
              headers.entries
                  .where((e) => e.value != null)
                  .map((e) => MapEntry(e.key, e.value!)),
            )
          : const <String, String>{};

      final response = await http
          .get(uri, headers: resolvedHeaders)
          .timeout(const Duration(seconds: 30));

      return response.body;
    } on Exception catch (exception) {
      BetterPlayerUtils.log('GetDataFromUrl failed: $exception');
      return null;
    }
  }
}

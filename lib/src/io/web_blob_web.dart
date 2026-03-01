// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:typed_data';
// ignore: deprecated_member_use
import 'dart:html' as html;

/// Creates an object URL (blob URL) from raw bytes, suitable for use as a
/// video source on web.
String? createBlobUrl(List<int> bytes, {String mimeType = 'video/mp4'}) {
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  return html.Url.createObjectUrl(blob);
}

/// Revokes a previously created blob URL to free memory.
void revokeBlobUrl(String url) => html.Url.revokeObjectUrl(url);

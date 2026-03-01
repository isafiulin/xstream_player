/// Native stub — blob URLs are only available on web.
String? createBlobUrl(List<int> bytes, {String mimeType = 'video/mp4'}) => null;

void revokeBlobUrl(String url) {}

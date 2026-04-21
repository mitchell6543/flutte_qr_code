import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

/// Triggers a file download in the browser (PNG bytes).
void downloadPngInBrowser(Uint8List bytes, String filename) {
  final blob = Blob(
    [bytes.toJS].toJS,
    BlobPropertyBag(type: 'image/png'),
  );
  final url = URL.createObjectURL(blob);
  final anchor = HTMLAnchorElement()
    ..href = url
    ..download = filename;
  document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}

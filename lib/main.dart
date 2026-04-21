import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import 'download_png.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus, XFile;

/// Shared with [PrettyQrView.data] and [QrImage.toImageAsBytes].
const PrettyQrDecoration _kQrDecoration = PrettyQrDecoration(
  image: PrettyQrDecorationImage(
    image: AssetImage('assets/app-icon-rounded.png'),
    padding: EdgeInsets.all(4),
    filterQuality: FilterQuality.high,
    isAntiAlias: true,
  ),
  shape: PrettyQrSmoothSymbol(
    color: PrettyQrBrush.gradient(
      gradient: LinearGradient(
        colors: [
          Color(0xFF6A41F6),
          Color(0xFFA032E9),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
  ),
  background: Colors.white,
  quietZone: PrettyQrQuietZone.pixels(16),
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _urlController = TextEditingController(
    text: 'https://apps.apple.com/hk/iphone/search?term=travel%20jumbo&pt=edm&ct=email&mt=launch_promo',
  );
  bool _saving = false;

  /// Payload for [PrettyQrView]; updated on a short debounce so [QrImage] is not
  /// rebuilt on every keystroke (see pretty_qr_code: avoid encoding in build).
  late String _qrPayload;
  Timer? _qrDebounce;

  static String _payloadForText(String raw) {
    final t = raw.trim();
    return t.isEmpty ? 'https://www.google.com' : t;
  }

  @override
  void initState() {
    super.initState();
    _qrPayload = _payloadForText(_urlController.text);
    _urlController.addListener(_onUrlTextChanged);
  }

  void _onUrlTextChanged() {
    _qrDebounce?.cancel();
    _qrDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final next = _payloadForText(_urlController.text);
      if (next != _qrPayload) {
        setState(() => _qrPayload = next);
      }
    });
  }

  /// Applies the latest field text to [_qrPayload] immediately (e.g. before save).
  void _syncQrPayloadToField() {
    _qrDebounce?.cancel();
    final next = _payloadForText(_urlController.text);
    if (next != _qrPayload) {
      setState(() => _qrPayload = next);
    }
  }

  @override
  void dispose() {
    _qrDebounce?.cancel();
    _urlController.removeListener(_onUrlTextChanged);
    _urlController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _encodeQrPngBytes() async {
    if (!mounted) return null;
    final qrCode = QrCode.fromData(
      data: _qrPayload,
      errorCorrectLevel: QrErrorCorrectLevel.H,
    );
    final qrImage = QrImage(qrCode);
    final configuration = createLocalImageConfiguration(context);
    final byteData = await qrImage.toImageAsBytes(
      size: 512,
      decoration: _kQrDecoration,
      configuration: configuration,
    );
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveQrImage() async {
    _syncQrPayloadToField();
    setState(() => _saving = true);
    try {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      final bytes = await _encodeQrPngBytes();
      if (!mounted) return;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not capture the QR code')),
        );
        return;
      }

      final file = XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: 'qr_code.png',
      );

      if (kIsWeb) {
        downloadPngInBrowser(bytes, 'qr_code.png');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image download started')),
        );
        return;
      }

      try {
        if (!await Gal.hasAccess()) {
          await Gal.requestAccess();
        }
        await Gal.putImageBytes(bytes, name: 'qr_code');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to your photo library')),
        );
      } on GalException {
        await SharePlus.instance.share(
          ShareParams(
            files: [file],
            downloadFallbackEnabled: true,
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Use Share to save the image to Photos or Files'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('QR Code Generator'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'URL',
                  hintText: 'https://example.com',
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                autocorrect: false,
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: min(280, MediaQuery.of(context).size.width * 0.80),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.white,
                      child: PrettyQrView.data(
                        key: ValueKey(_qrPayload),
                        data: _qrPayload,
                        errorCorrectLevel: QrErrorCorrectLevel.H,
                        decoration: _kQrDecoration,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveQrImage,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_alt),
                label: Text(_saving ? 'Saving…' : 'Save QR as image'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

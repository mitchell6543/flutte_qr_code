import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';

import 'download_png.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus, XFile;

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
  final GlobalKey _qrKey = GlobalKey();
  final TextEditingController _urlController = TextEditingController(
    text: 'https://www.google.com',
  );
  bool _saving = false;

  String get _qrData {
    final t = _urlController.text.trim();
    return t.isEmpty ? 'https://www.google.com' : t;
  }

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  void _onUrlChanged() => setState(() {});

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureQrPng() async {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return null;
    final boundary =
        _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: dpr);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveQrImage() async {
    setState(() => _saving = true);
    try {
      final bytes = await _captureQrPng();
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
                  child: RepaintBoundary(
                    key: _qrKey,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Colors.white,
                        child: PrettyQrView.data(
                          key: ValueKey(_qrData),
                          data: _qrData,
                          decoration: const PrettyQrDecoration(
                            image: PrettyQrDecorationImage(
                              image: AssetImage(
                                'assets/app-icon-rounded.png',
                              ),
                              scale: 0.2,
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
                            quietZone: PrettyQrQuietZone.pixels(18),
                          ),
                        ),
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

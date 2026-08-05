import 'dart:async' show TimeoutException, unawaited;
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/kid_word_recording_service.dart';

const _sfxOptag = 'assets/Optag.mp3';
const _sfxOptagStop = 'assets/Optag_stop.mp3';
const _sfxOptagGem = 'assets/Optag_gem.mp3';
const _sfxOptagNy = 'assets/Optag_ny.mp3';

/// Bundmodal: optag ord med korte UI-lyd fra assets, gem til [kid_word_recordings].
class KidWordRecordMenu extends StatefulWidget {
  const KidWordRecordMenu({
    super.key,
    required this.kidId,
    required this.normalizedWord,
    required this.displayWord,
    required this.hasExistingOwnRecording,
    this.onSaved,
  });

  final String kidId;
  final String normalizedWord;
  final String displayWord;
  final bool hasExistingOwnRecording;
  final VoidCallback? onSaved;

  @override
  State<KidWordRecordMenu> createState() => _KidWordRecordMenuState();
}

class _KidWordRecordMenuState extends State<KidWordRecordMenu> {
  late final AudioPlayer _sfx;
  final AudioRecorder _rec = AudioRecorder();
  bool _sfxBusy = false;
  bool _sfxInited = false;
  bool _recording = false;
  bool _hasTempFile = false;
  String? _tempPath;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sfx = AudioPlayer();
    unawaited(_initSfxAndHints());
  }

  /// Samme mønster som [KidSpilPvpScreen] — `just_audio`+asset lød ikke på nogle enheder.
  Future<void> _initSfx() async {
    if (_sfxInited) return;
    _sfxInited = true;
    try {
      await _sfx.setPlayerMode(PlayerMode.mediaPlayer);
      _sfx.audioCache.prefix = '';
      await _sfx.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('KidWordRecordMenu audio init: $e');
      }
    }
  }

  Future<void> _initSfxAndHints() async {
    await _initSfx();
    if (!mounted) return;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      unawaited(_playOpenHints());
    }
  }

  Future<void> _playSfx(String asset) async {
    if (_sfxBusy) return;
    _sfxBusy = true;
    try {
      await _sfx.stop();
      // Samme sti som spil-MP3: `assets/Optag.mp3` osv. (jævnfør pubspec: assets/)
      await _sfx.play(AssetSource(asset));
      try {
        await _sfx.onPlayerComplete.first
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        // Længde ukendt / stream kom ikke
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('kid_word_record SFX: $e (asset: $asset)');
      }
    } finally {
      _sfxBusy = false;
    }
  }

  /// Efter [Stop]: afspil den optagede fil, derefter [Optag_gem.mp3].
  Future<void> _playRecordingThenGemSfx(String recordingPath) async {
    _sfxBusy = true;
    try {
      await _initSfx();
      await _sfx.stop();
      final f = File(recordingPath);
      if (await f.exists() && await f.length() >= 1) {
        try {
          await _sfx.play(
            DeviceFileSource(
              f.path,
              mimeType: 'audio/mp4',
            ),
          );
          try {
            await _sfx.onPlayerComplete.first
                .timeout(const Duration(minutes: 2));
          } on TimeoutException {
            // optagelsens længde ukendt
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('kid_word_record: afspilning af optagelse: $e');
          }
          await _sfx.stop();
        }
      }
      await _sfx.stop();
      await _sfx.play(AssetSource(_sfxOptagGem));
      try {
        await _sfx.onPlayerComplete.first
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        // færdig-signal manglede
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('kid_word_record Optag_gem: $e');
      }
    } finally {
      _sfxBusy = false;
    }
  }

  Future<void> _playOpenHints() async {
    if (widget.hasExistingOwnRecording) {
      await _playSfx(_sfxOptagNy);
      return;
    }
    await _playSfx(_sfxOptag);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _playSfx(_sfxOptagStop);
  }

  @override
  void dispose() {
    unawaited(_rec.dispose());
    unawaited(_sfx.dispose());
    super.dispose();
  }

  Future<String> _newTempM4A() async {
    final d = await getTemporaryDirectory();
    return '${d.path}/kid_w_${widget.normalizedWord.hashCode}_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<void> _startRecord() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (mounted) {
        setState(
          () => _error = 'Optagelse findes i appen på iPad/telefon.',
        );
      }
      return;
    }
    if (!await _rec.hasPermission()) {
      if (mounted) {
        setState(
          () => _error = 'Mikrofonen er ikke tilladt. Slå det til i indstillinger.',
        );
      }
      return;
    }
    setState(() {
      _error = null;
      _hasTempFile = false;
    });
    _tempPath = await _newTempM4A();
    await _rec.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _tempPath!,
    );
    if (mounted) {
      setState(() => _recording = true);
    }
  }

  Future<void> _stopRecord() async {
    if (!_recording) return;
    String? pth;
    try {
      pth = await _rec.stop();
    } catch (e) {
      debugPrint('rec stop: $e');
    }
    if (mounted) {
      setState(() {
        _recording = false;
        if (pth != null) {
          _tempPath = pth;
          _hasTempFile = true;
        }
      });
    }
    if (pth != null && pth.isNotEmpty) {
      await _playRecordingThenGemSfx(pth);
    }
  }

  Future<void> _save() async {
    if (!_hasTempFile || _tempPath == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await KidWordRecordingService.saveRecording(
        kidId: widget.kidId,
        word: widget.normalizedWord,
        filePath: _tempPath!,
      );
      if (mounted) {
        widget.onSaved?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRecordOnDevice =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sig ordet højt',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3E2723),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '«${widget.displayWord}»',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF5A1A0D),
              ),
            ),
            if (widget.hasExistingOwnRecording) ...[
              const SizedBox(height: 6),
              Text(
                'Hvis du gemmer, erstatter du den gamle lyd for dette ord overalt i bøgerne.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.brown.shade800,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
            const SizedBox(height: 20),
            if (!canRecordOnDevice)
              const Text(
                'På web og nogle platforme kan man ikke optage. Brug iPad eller telefon.',
                textAlign: TextAlign.center,
              )
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : (_recording ? _stopRecord : _startRecord),
                      icon: Icon(_recording ? Icons.stop : Icons.mic, size: 30),
                      label: Text(
                        _recording ? 'Stop' : 'Optag',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: (!_hasTempFile || _saving) ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Gem', style: TextStyle(fontSize: 20)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Luk'),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../constants/api_keys.dart';

// ── Call state machine ───────────────────────────────────────────────────────

enum AiCallState {
  idle,
  initializing, // STT init + audio setup
  playingOpening, // opening line via ElevenLabs
  listening, // mic active, waiting for user
  processing, // Claude + ElevenLabs API calls in flight
  speaking, // AI audio playing
  error,
}

// ── AI Characters ────────────────────────────────────────────────────────────

enum AiCharacter { papa, mummy, police, bhai }

extension AiCharacterExt on AiCharacter {
  String get displayName {
    switch (this) {
      case AiCharacter.papa:
        return 'Papa';
      case AiCharacter.mummy:
        return 'Mummy';
      case AiCharacter.police:
        return 'Inspector Sharma';
      case AiCharacter.bhai:
        return 'Bhai';
    }
  }

  String get avatarEmoji {
    switch (this) {
      case AiCharacter.papa:
        return '👨';
      case AiCharacter.mummy:
        return '👩';
      case AiCharacter.police:
        return '👮';
      case AiCharacter.bhai:
        return '🧑';
    }
  }

  String get voiceId {
    switch (this) {
      case AiCharacter.papa:
        return ApiKeys.elevenLabsPapaVoiceId;
      case AiCharacter.mummy:
        return ApiKeys.elevenLabsMummyVoiceId;
      case AiCharacter.police:
        return ApiKeys.elevenLabsPoliceVoiceId;
      case AiCharacter.bhai:
        return ApiKeys.elevenLabsBhaiVoiceId;
    }
  }

  String get systemPrompt {
    switch (this) {
      case AiCharacter.papa:
        return 'Tu ek caring Indian father hai. User teri beti hai jo mushkil '
            'mein hai. Chhoti, natural Hindi mein baat kar jaise real phone '
            'call ho. Max 2-3 sentences per response. Protective aur '
            'reassuring reh. Sirf Hindi mein respond kar — English avoid kar.\n'
            'Example: "Haan beta, kya hua? Main abhi aa raha hoon, ghabra mat."';

      case AiCharacter.mummy:
        return 'Tu ek loving Indian mother hai. User teri beti hai jo darri '
            'hui hai. Emotional aur caring Hindi mein baat kar. Max 2-3 '
            'sentences. Sirf Hindi mein respond kar.\n'
            'Example: "Arre beta, kya hua? Main nikal rahi hoon abhi, ruk wahan."';

      case AiCharacter.police:
        return 'Tu ek professional Lucknow Police Inspector hai (Inspector '
            'Sharma). Official aur authoritative Hindi mein baat kar. Max '
            '2-3 sentences. Sirf Hindi mein respond kar. Professional rehna.\n'
            'Example: "Haan ji, aapka message mila. Hum 5 minute mein pahunch rahe hain."';

      case AiCharacter.bhai:
        return 'Tu ek protective Indian bada bhai hai. Casual aur aggressive '
            'protective tone. Simple Hindi mein baat kar. Max 2-3 sentences. '
            'Sirf Hindi mein respond kar. Confident rehna.\n'
            'Example: "Haan bata kya hua? Koi hai wahan? Main aa raha hoon abhi."';
    }
  }

  String get openingLine {
    switch (this) {
      case AiCharacter.papa:
        return 'Haan beta, main bol raha hoon. Kya hua?';
      case AiCharacter.mummy:
        return 'Haan beti, main hoon. Sab theek hai?';
      case AiCharacter.police:
        return 'Haan ji, Inspector Sharma speaking. Aapne call kiya?';
      case AiCharacter.bhai:
        return 'Haan bol, kya hua?';
    }
  }

  String get timeoutFallback {
    switch (this) {
      case AiCharacter.papa:
        return 'Beta awaaz nahi aa rahi. Main abhi aa raha hoon, ghabra mat.';
      case AiCharacter.mummy:
        return 'Beti main sun nahi pa rahi. Ruk, main aa rahi hoon abhi.';
      case AiCharacter.police:
        return 'Awaaz saaf nahi aa rahi. Hum pahunch rahe hain aapke paas.';
      case AiCharacter.bhai:
        return 'Kuch sunai nahi de raha. Ruk, main aa raha hoon.';
    }
  }
}

// ── Conversation message ─────────────────────────────────────────────────────

class ConversationMessage {
  const ConversationMessage({required this.role, required this.text});
  final String role; // 'user' | 'assistant'
  final String text;
}

// ── AI Call Service ──────────────────────────────────────────────────────────

/// Manages the full AI fake call pipeline:
/// Speech → Claude → ElevenLabs → Audio out
///
/// Usage:
///   await AiCallService.instance.startCall(AiCharacter.papa);
///   // ... callbacks fire as state changes ...
///   await AiCallService.instance.endCall();
class AiCallService {
  AiCallService._();
  static final AiCallService instance = AiCallService._();

  // ── Native STREAM_ALARM channel ───────────────────────────────────────────
  static const _audioChannel = MethodChannel('com.rakshaapp.raksha/audio');

  // ── Audio output player ───────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Speech-to-text ────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;

  // ── HTTP client (kept alive across requests) ──────────────────────────────
  final http.Client _http = http.Client();

  // ── Internal state ────────────────────────────────────────────────────────
  AiCallState _state = AiCallState.idle;
  AiCharacter _character = AiCharacter.papa;
  bool _callActive = false;
  StreamSubscription? _playerSub;

  // ── Conversation history (capped at _maxHistory messages) ─────────────────
  final List<ConversationMessage> _history = [];
  static const int _maxHistory = 6;

  // ── Public callbacks ──────────────────────────────────────────────────────
  /// Fires on every state transition — use this to update UI.
  void Function(AiCallState state)? onStateChanged;

  /// Fires while user is speaking (partial transcript for live display).
  void Function(String transcript)? onPartialTranscript;

  /// Fires when the AI has generated a text response (before audio plays).
  void Function(String text, bool isUser)? onMessageAdded;

  /// Fires when the call has fully ended and audio cleaned up.
  void Function()? onCallEnded;

  /// Fires on unrecoverable error.
  void Function(String message)? onError;

  // ── Getters ───────────────────────────────────────────────────────────────
  AiCallState get state => _state;
  AiCharacter get character => _character;
  bool get isCallActive => _callActive;
  List<ConversationMessage> get history => List.unmodifiable(_history);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Begin an AI conversation call with [character].
  Future<void> startCall(AiCharacter character) async {
    if (_callActive) await endCall();

    _character = character;
    _callActive = true;
    _history.clear();
    _setState(AiCallState.initializing);

    // 1. Initialise speech-to-text
    _speechAvailable = await _speech.initialize(
      onError: (e) {
        if (_callActive && _state == AiCallState.listening) {
          // Transient errors → retry
          Future.delayed(
            const Duration(seconds: 1),
            () { if (_callActive) _startListening(); },
          );
        }
      },
      onStatus: (_) {},
    );

    // 2. Route audio to STREAM_ALARM (bypasses silent mode)
    if (Platform.isAndroid) {
      await _audioChannel.invokeMethod('setAlarmStream');
      await _audioChannel.invokeMethod('setMaxAlarmVolume');
    }

    // 3. Play opening line
    await _playOpeningLine();
  }

  /// Gracefully end the call and release all resources.
  Future<void> endCall() async {
    _callActive = false;
    _playerSub?.cancel();
    _playerSub = null;

    await _speech.cancel();
    await _player.stop();

    if (Platform.isAndroid) {
      try {
        await _audioChannel.invokeMethod('restoreVolume');
      } catch (_) {}
    }

    _history.clear();
    _setState(AiCallState.idle);
    onCallEnded?.call();
  }

  void dispose() {
    _callActive = false;
    _speech.cancel();
    _player.dispose();
    _http.close();
  }

  // ── Pipeline steps ────────────────────────────────────────────────────────

  Future<void> _playOpeningLine() async {
    if (!_callActive) return;
    _setState(AiCallState.playingOpening);

    final opening = _character.openingLine;
    _addToHistory('assistant', opening);
    onMessageAdded?.call(opening, false);

    try {
      final bytes =
          await _textToSpeech(opening).timeout(const Duration(seconds: 6));
      await _playBytes(bytes);
    } catch (_) {
      // Fallback: pre-recorded asset
      await _playAssetFallback();
    }

    if (_callActive) _startListening();
  }

  void _startListening() {
    if (!_callActive) return;
    if (!_speechAvailable) {
      _setState(AiCallState.error);
      onError?.call('Microphone unavailable. Check permissions.');
      return;
    }

    _setState(AiCallState.listening);

    _speech.listen(
      onResult: _onSpeechResult,
      localeId: 'hi_IN',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!_callActive) return;

    // Live partial display
    if (result.recognizedWords.isNotEmpty) {
      onPartialTranscript?.call(result.recognizedWords);
    }

    if (result.finalResult) {
      final text = result.recognizedWords.trim();
      if (text.isEmpty) {
        // Nothing heard → keep listening
        _startListening();
      } else {
        _processUserSpeech(text);
      }
    }
  }

  Future<void> _processUserSpeech(String userText) async {
    if (!_callActive) return;
    _setState(AiCallState.processing);

    _addToHistory('user', userText);
    onMessageAdded?.call(userText, true);

    try {
      // ── Claude ────────────────────────────────────────────────────────────
      final aiText =
          await _callClaude().timeout(const Duration(seconds: 6));
      if (!_callActive) return;

      _addToHistory('assistant', aiText);
      onMessageAdded?.call(aiText, false);

      // ── ElevenLabs ────────────────────────────────────────────────────────
      _setState(AiCallState.speaking);
      final bytes =
          await _textToSpeech(aiText).timeout(const Duration(seconds: 6));
      await _playBytes(bytes);
    } on TimeoutException {
      await _speakFallback();
    } catch (_) {
      await _speakFallback();
    }

    if (_callActive) _startListening();
  }

  // ── Claude API ────────────────────────────────────────────────────────────

  Future<String> _callClaude() async {
    // Build message list from history (exclude the current user turn —
    // it was just added, so it IS the last entry).
    final messages = _history
        .map((m) => {'role': m.role, 'content': m.text})
        .toList();

    final response = await _http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': ApiKeys.claudeApiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': ApiKeys.claudeModel,
        'max_tokens': 150,
        'system': _character.systemPrompt,
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    final content = (data['content'] as List).first as Map;
    return (content['text'] as String).trim();
  }

  // ── ElevenLabs TTS ────────────────────────────────────────────────────────

  Future<Uint8List> _textToSpeech(String text) async {
    final response = await _http.post(
      Uri.parse(
          'https://api.elevenlabs.io/v1/text-to-speech/${_character.voiceId}'),
      headers: {
        'xi-api-key': ApiKeys.elevenLabsApiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: jsonEncode({
        'text': text,
        'model_id': 'eleven_multilingual_v2',
        'voice_settings': {
          'stability': 0.55,
          'similarity_boost': 0.75,
          'style': 0.0,
          'use_speaker_boost': true,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('ElevenLabs ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  // ── Audio playback ────────────────────────────────────────────────────────

  Future<void> _playBytes(Uint8List bytes) async {
    if (!_callActive) return;
    _setState(AiCallState.speaking);

    final completer = Completer<void>();
    _playerSub?.cancel();
    _playerSub = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });

    await _player.play(BytesSource(bytes));
    await completer.future;

    _playerSub?.cancel();
    _playerSub = null;
  }

  Future<void> _playAssetFallback() async {
    if (!_callActive) return;
    _setState(AiCallState.speaking);
    try {
      final completer = Completer<void>();
      _playerSub?.cancel();
      _playerSub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _player.play(AssetSource('audios/fake_call_voice.mp3'));
      await completer.future
          .timeout(const Duration(seconds: 15), onTimeout: () {});
      _playerSub?.cancel();
      _playerSub = null;
    } catch (_) {}
  }

  Future<void> _speakFallback() async {
    if (!_callActive) return;
    final fallback = _character.timeoutFallback;
    _addToHistory('assistant', fallback);
    onMessageAdded?.call(fallback, false);
    _setState(AiCallState.speaking);

    try {
      // Try TTS for the fallback line (4 s budget)
      final bytes =
          await _textToSpeech(fallback).timeout(const Duration(seconds: 4));
      await _playBytes(bytes);
    } catch (_) {
      await _playAssetFallback();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setState(AiCallState s) {
    _state = s;
    onStateChanged?.call(s);
  }

  void _addToHistory(String role, String text) {
    _history.add(ConversationMessage(role: role, text: text));
    while (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
  }
}

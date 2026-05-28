// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../constants/api_keys.dart';

// ── SOS State ────────────────────────────────────────────────────────────────

enum SosState { idle, locating, sending, active, resolving, error }

// ── Emergency Contact model ───────────────────────────────────────────────────

class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
    this.alerted = false,
  });
  final String name;
  final String phone;
  final String relation;
  final bool alerted;

  EmergencyContact copyWith({bool? alerted}) =>
      EmergencyContact(
        name: name,
        phone: phone,
        relation: relation,
        alerted: alerted ?? this.alerted,
      );
}

// ── SOS Alert data ────────────────────────────────────────────────────────────

class SosAlertData {
  const SosAlertData({
    required this.alertId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.mapsLink,
    required this.userName,
    required this.contacts,
    required this.triggeredAt,
  });
  final String alertId;
  final double latitude;
  final double longitude;
  final String address;
  final String mapsLink;
  final String userName;
  final List<EmergencyContact> contacts;
  final DateTime triggeredAt;
}

// ── SOS Service ───────────────────────────────────────────────────────────────

/// Central service for the entire SOS pipeline:
/// Location → Firestore → MSG91 SMS → WhatsApp
class SosService {
  SosService._();
  static final SosService instance = SosService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _http = http.Client();

  // ── State ──────────────────────────────────────────────────────────────────
  SosState _state = SosState.idle;
  SosAlertData? _activeAlert;
  Timer? _locationUpdateTimer;

  // ── Callbacks ──────────────────────────────────────────────────────────────
  void Function(SosState)? onStateChanged;
  void Function(SosAlertData)? onAlertCreated;
  void Function(double lat, double lng, String address)? onLocationUpdated;
  void Function(String message)? onError;
  void Function(String contactName, bool success)? onContactAlerted;

  // ── Getters ────────────────────────────────────────────────────────────────
  SosState get state => _state;
  SosAlertData? get activeAlert => _activeAlert;
  bool get isActive => _state == SosState.active;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Full SOS trigger pipeline.
  Future<void> triggerSOS() async {
    if (_state == SosState.active || _state == SosState.sending) return;

    try {
      // 1. Get location
      _setState(SosState.locating);
      final position = await _getLocation();
      final address = await _getAddress(position.latitude, position.longitude);
      final mapsLink =
          'https://maps.google.com/?q=${position.latitude},${position.longitude}';

      // 2. Get user info
      final userId = _auth.currentUser?.uid ?? '';
      final userName = await _getUserName(userId);

      // 3. Fetch emergency contacts
      final contacts = await _fetchContacts(userId);

      // 4. Save to Firestore
      _setState(SosState.sending);
      final alertId = await _saveAlert(
        userId: userId,
        userName: userName,
        lat: position.latitude,
        lng: position.longitude,
        address: address,
        mapsLink: mapsLink,
      );

      final alertData = SosAlertData(
        alertId: alertId,
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        mapsLink: mapsLink,
        userName: userName,
        contacts: contacts,
        triggeredAt: DateTime.now(),
      );
      _activeAlert = alertData;

      // 5. Alert contacts (parallel)
      await _alertContacts(alertData);

      // 6. Start live location updates (every 30s)
      _startLocationUpdates(alertId);

      _setState(SosState.active);
      onAlertCreated?.call(alertData);
    } catch (e) {
      _setState(SosState.error);
      onError?.call('SOS failed: $e');
      // Offline fallback
      await _offlineFallback();
    }
  }

  /// Mark SOS as resolved — notify contacts + update Firestore.
  Future<void> markSafe() async {
    if (_activeAlert == null) return;
    _setState(SosState.resolving);
    _locationUpdateTimer?.cancel();

    final alert = _activeAlert!;
    final userId = _auth.currentUser?.uid ?? '';

    try {
      // Update Firestore
      await _firestore
          .collection('sos_alerts')
          .doc(alert.alertId)
          .update({'status': 'resolved', 'resolvedAt': FieldValue.serverTimestamp()});

      // Send "safe" SMS to all contacts
      final safeMsg = '✅ RAKSHA: ${alert.userName} ab surakshit hain. '
          'Alarm resolve ho gaya. - RAKSHA Safety App';

      for (final contact in alert.contacts) {
        await _sendMsg91SMS(phone: contact.phone, message: safeMsg);
      }
    } catch (_) {}

    _activeAlert = null;
    _setState(SosState.idle);
  }

  void dispose() {
    _locationUpdateTimer?.cancel();
    _http.close();
  }

  // ── Location ───────────────────────────────────────────────────────────────

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  Future<String> _getAddress(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty).toList();
        return parts.join(', ');
      }
    } catch (_) {}
    return '$lat, $lng';
  }

  void _startLocationUpdates(String alertId) {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        try {
          final pos = await _getLocation();
          final addr = await _getAddress(pos.latitude, pos.longitude);
          final link = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';

          await _firestore.collection('sos_alerts').doc(alertId).update({
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'address': addr,
            'mapsLink': link,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          onLocationUpdated?.call(pos.latitude, pos.longitude, addr);
        } catch (_) {}
      },
    );
  }

  // ── Firestore ──────────────────────────────────────────────────────────────

  Future<String> _getUserName(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return (doc.data()?['name'] as String?) ?? 'RAKSHA User';
    } catch (_) {
      return _auth.currentUser?.displayName ?? 'RAKSHA User';
    }
  }

  Future<List<EmergencyContact>> _fetchContacts(String userId) async {
    try {
      final snap = await _firestore
          .collection('emergency_contacts')
          .where('userId', isEqualTo: userId)
          .get();

      return snap.docs.map((doc) {
        final d = doc.data();
        return EmergencyContact(
          name: (d['name'] as String?) ?? 'Contact',
          phone: (d['phone'] as String?) ?? '',
          relation: (d['relation'] as String?) ?? '',
        );
      }).where((c) => c.phone.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String> _saveAlert({
    required String userId,
    required String userName,
    required double lat,
    required double lng,
    required String address,
    required String mapsLink,
  }) async {
    final ref = await _firestore.collection('sos_alerts').add({
      'userId': userId,
      'userName': userName,
      'latitude': lat,
      'longitude': lng,
      'address': address,
      'mapsLink': mapsLink,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'active',
    });
    return ref.id;
  }

  // ── Contact alerting ───────────────────────────────────────────────────────

  Future<void> _alertContacts(SosAlertData alert) async {
    final timeStr = _formatTime(alert.triggeredAt);
    final msg = '🚨 RAKSHA SOS ALERT!\n'
        '${alert.userName} ko turant madad chahiye!\n'
        '📍 Location: ${alert.address}\n'
        '🗺️ Map: ${alert.mapsLink}\n'
        '⏰ $timeStr\n'
        'RAKSHA Safety App';

    bool whatsappOpened = false;

    for (int i = 0; i < alert.contacts.length; i++) {
      final contact = alert.contacts[i];
      bool success = false;

      try {
        success = await _sendMsg91SMS(phone: contact.phone, message: msg);
      } catch (_) {}

      onContactAlerted?.call(contact.name, success);

      // Open WhatsApp for first contact only
      if (i == 0 && !whatsappOpened) {
        try {
          await _openWhatsApp(phone: contact.phone, message: msg);
          whatsappOpened = true;
        } catch (_) {}
      }
    }
  }

  // ── MSG91 SMS ──────────────────────────────────────────────────────────────

  Future<bool> _sendMsg91SMS({
    required String phone,
    required String message,
  }) async {
    // Normalize phone: ensure +91 prefix for India
    String normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (normalizedPhone.length == 10) normalizedPhone = '91$normalizedPhone';

    try {
      final response = await _http.get(
        Uri.parse('https://api.msg91.com/api/sendhttp.php').replace(
          queryParameters: {
            'authkey': ApiKeys.msg91AuthKey,
            'mobiles': normalizedPhone,
            'message': message,
            'sender': ApiKeys.msg91SenderId,
            'route': '4', // Transactional route
            'country': '91',
            'unicode': '1', // UTF-8 for Hindi + emojis
          },
        ),
      ).timeout(const Duration(seconds: 8));

      return response.statusCode == 200 &&
          !response.body.toLowerCase().contains('error');
    } catch (_) {
      return false;
    }
  }

  // ── WhatsApp ───────────────────────────────────────────────────────────────

  Future<void> _openWhatsApp({
    required String phone,
    required String message,
  }) async {
    String normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (normalizedPhone.length == 10) normalizedPhone = '91$normalizedPhone';

    final encoded = Uri.encodeComponent(message);
    final waUrl = Uri.parse('https://wa.me/$normalizedPhone?text=$encoded');

    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    }
  }

  // ── Offline fallback ───────────────────────────────────────────────────────

  Future<void> _offlineFallback() async {
    // Try opening device SMS app with pre-filled message
    try {
      final alert = _activeAlert;
      if (alert == null) return;

      final phones = alert.contacts.map((c) => c.phone).join(',');
      final msg = Uri.encodeComponent(
        '🚨 SOS ALERT! ${alert.userName} ko madad chahiye! '
        'Map: ${alert.mapsLink}',
      );

      final smsUri = Uri.parse('sms:$phones?body=$msg');
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setState(SosState s) {
    _state = s;
    onStateChanged?.call(s);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

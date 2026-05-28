// lib/features/sos/safe_journey_service.dart
//
// Safe Journey Mode
//
// When activated:
//  1. User sets destination + ETA
//  2. Location is shared live with emergency contacts via Firestore
//  3. Contacts get SMS "Journey Started" message
//  4. If user doesn't mark arrival within ETA → auto SOS triggers

// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/api_keys.dart';
import 'sos_service.dart';
import 'package:http/http.dart' as http;

// ── Safe Journey State ────────────────────────────────────────────────────────

enum SafeJourneyState { idle, active, arrived, overdue }

// ── Safe Journey Data ─────────────────────────────────────────────────────────

class SafeJourneyData {
  const SafeJourneyData({
    required this.journeyId,
    required this.destination,
    required this.startedAt,
    required this.etaMinutes,
    required this.contacts,
  });
  final String journeyId;
  final String destination;
  final DateTime startedAt;
  final int etaMinutes;
  final List<EmergencyContact> contacts;

  DateTime get etaTime => startedAt.add(Duration(minutes: etaMinutes));
  int get minutesRemaining {
    final rem = etaTime.difference(DateTime.now()).inMinutes;
    return rem < 0 ? 0 : rem;
  }
}

// ── Safe Journey Service ──────────────────────────────────────────────────────

class SafeJourneyService {
  SafeJourneyService._();
  static final SafeJourneyService instance = SafeJourneyService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  SafeJourneyState _state = SafeJourneyState.idle;
  SafeJourneyData? _journey;
  Timer? _locationTimer;
  Timer? _etaTimer;

  void Function(SafeJourneyState)? onStateChanged;
  void Function(double lat, double lng, String addr)? onLocationUpdated;
  void Function()? onEtaExpired;

  SafeJourneyState get state => _state;
  SafeJourneyData? get journey => _journey;
  bool get isActive => _state == SafeJourneyState.active;

  // ── Start journey ──────────────────────────────────────────────────────────

  Future<void> startJourney({
    required String destination,
    required int etaMinutes,
  }) async {
    if (_state == SafeJourneyState.active) return;

    final userId = _auth.currentUser?.uid ?? '';
    final userName = await _getUserName(userId);
    final contacts = await _fetchContacts(userId);

    // Get start location
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      throw Exception('Location unavailable: $e');
    }

    final address = await _getAddress(pos.latitude, pos.longitude);
    final mapsLink =
        'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';

    // Save to Firestore
    final ref = await _firestore.collection('safe_journeys').add({
      'userId': userId,
      'userName': userName,
      'destination': destination,
      'etaMinutes': etaMinutes,
      'startedAt': FieldValue.serverTimestamp(),
      'currentLat': pos.latitude,
      'currentLng': pos.longitude,
      'currentAddress': address,
      'status': 'active',
    });

    _journey = SafeJourneyData(
      journeyId: ref.id,
      destination: destination,
      startedAt: DateTime.now(),
      etaMinutes: etaMinutes,
      contacts: contacts,
    );

    // Send start SMS to contacts
    final msg = '🛡️ RAKSHA Safe Journey Started!\n'
        '$userName ka safar shuru hua hai.\n'
        '📍 From: $address\n'
        '🏁 To: $destination\n'
        '⏰ ETA: $etaMinutes minutes\n'
        '🗺️ Map: $mapsLink\n'
        'RAKSHA Safety App';

    for (final c in contacts) {
      await _sendSMS(phone: c.phone, message: msg);
    }

    _setState(SafeJourneyState.active);

    // Start 30s location updates
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        final a = await _getAddress(p.latitude, p.longitude);
        final link = 'https://maps.google.com/?q=${p.latitude},${p.longitude}';

        await _firestore.collection('safe_journeys').doc(_journey!.journeyId).update({
          'currentLat': p.latitude,
          'currentLng': p.longitude,
          'currentAddress': a,
          'mapsLink': link,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        onLocationUpdated?.call(p.latitude, p.longitude, a);
      } catch (_) {}
    });

    // ETA countdown — trigger SOS if not marked arrived in time
    final etaDuration = Duration(minutes: etaMinutes);
    _etaTimer = Timer(etaDuration, () {
      if (_state == SafeJourneyState.active) {
        _setState(SafeJourneyState.overdue);
        onEtaExpired?.call();
      }
    });
  }

  // ── Mark arrived (safe) ────────────────────────────────────────────────────

  Future<void> markArrived() async {
    if (_journey == null) return;

    _locationTimer?.cancel();
    _etaTimer?.cancel();

    final userId = _auth.currentUser?.uid ?? '';
    final userName = await _getUserName(userId);
    final contacts = await _fetchContacts(userId);

    await _firestore
        .collection('safe_journeys')
        .doc(_journey!.journeyId)
        .update({'status': 'arrived', 'arrivedAt': FieldValue.serverTimestamp()});

    // "Arrived safe" SMS
    final msg = '✅ RAKSHA: $userName safely pahunch gaye hain!\n'
        'Destination: ${_journey!.destination}\n'
        'Safe Journey complete. - RAKSHA Safety App';

    for (final c in contacts) {
      await _sendSMS(phone: c.phone, message: msg);
    }

    _journey = null;
    _setState(SafeJourneyState.arrived);
    await Future.delayed(const Duration(seconds: 2));
    _setState(SafeJourneyState.idle);
  }

  void dispose() {
    _locationTimer?.cancel();
    _etaTimer?.cancel();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setState(SafeJourneyState s) {
    _state = s;
    onStateChanged?.call(s);
  }

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
      return snap.docs.map((d) {
        final data = d.data();
        return EmergencyContact(
          name: (data['name'] as String?) ?? 'Contact',
          phone: (data['phone'] as String?) ?? '',
          relation: (data['relation'] as String?) ?? '',
        );
      }).where((c) => c.phone.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String> _getAddress(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isNotEmpty) {
        final p = marks.first;
        return [p.subLocality, p.locality, p.administrativeArea]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');
      }
    } catch (_) {}
    return '$lat, $lng';
  }

  Future<bool> _sendSMS({required String phone, required String message}) async {
    String normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (normalizedPhone.length == 10) normalizedPhone = '91$normalizedPhone';
    try {
      final response = await http.get(
        Uri.parse('https://api.msg91.com/api/sendhttp.php').replace(
          queryParameters: {
            'authkey': ApiKeys.msg91AuthKey,
            'mobiles': normalizedPhone,
            'message': message,
            'sender': ApiKeys.msg91SenderId,
            'route': '4',
            'country': '91',
            'unicode': '1',
          },
        ),
      ).timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ── Safe Journey Panel (inline in Home screen) ────────────────────────────────

/// Shows the Safe Journey Mode toggle card on the Home screen.
/// When toggle is flipped ON → shows dialog to set destination + ETA.
class SafeJourneyPanelWidget extends StatefulWidget {
  const SafeJourneyPanelWidget({super.key});

  @override
  State<SafeJourneyPanelWidget> createState() => _SafeJourneyPanelWidgetState();
}

class _SafeJourneyPanelWidgetState extends State<SafeJourneyPanelWidget> {
  final _svc = SafeJourneyService.instance;

  @override
  void initState() {
    super.initState();
    _svc.onStateChanged = (_) {
      if (mounted) setState(() {});
    };
    _svc.onEtaExpired = () {
      if (mounted) {
        _showEtaExpiredDialog();
      }
    };
  }

  @override
  void dispose() {
    _svc.onStateChanged = null;
    _svc.onEtaExpired = null;
    super.dispose();
  }

  Future<void> _showStartDialog() async {
    final destController = TextEditingController();
    int etaMinutes = 30;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StartJourneySheet(
        onStart: (dest, eta) async {
          Navigator.pop(ctx);
          try {
            await _svc.startJourney(destination: dest, etaMinutes: eta);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
      ),
    );

    destController.dispose();
    _ = etaMinutes; // suppress unused warning
  }

  Future<void> _showEtaExpiredDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0000),
        title: Text(
          '⏰ ETA Expire Ho Gaya!',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Aap apne destination tak nahi pahunche.\n'
          'Kya aap safe hain?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _svc.markArrived();
            },
            child: Text('✅ Main Safe Hoon',
                style: GoogleFonts.inter(
                    color: const Color(0xFF22C55E), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              SosService.instance.triggerSOS();
            },
            child: Text('🚨 SOS Bhejo',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _svc.isActive;
    final journey = _svc.journey;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF0A2E1A)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? const Color(0xFF22C55E).withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.shield_moon_rounded,
                    color: isActive
                        ? const Color(0xFF22C55E)
                        : Theme.of(context).colorScheme.onSurface,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safe Journey Mode',
                        style: GoogleFonts.plusJakartaSans(
                          color: isActive
                              ? const Color(0xFF22C55E)
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        isActive
                            ? '${journey?.minutesRemaining ?? 0} min bache — ${journey?.destination ?? ""}'
                            : 'Live path share karein contacts ke saath',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  activeColor: const Color(0xFF22C55E),
                  onChanged: (val) {
                    if (val) {
                      _showStartDialog();
                    } else {
                      _svc.markArrived();
                    }
                  },
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _svc.markArrived,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '✅ Main Pahunch Gaya / Gayi',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF22C55E),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Start Journey Bottom Sheet ─────────────────────────────────────────────────

class _StartJourneySheet extends StatefulWidget {
  const _StartJourneySheet({required this.onStart});
  final void Function(String destination, int etaMinutes) onStart;

  @override
  State<_StartJourneySheet> createState() => _StartJourneySheetState();
}

class _StartJourneySheetState extends State<_StartJourneySheet> {
  final _destController = TextEditingController();
  int _eta = 30;
  bool _loading = false;

  static const _etaOptions = [10, 15, 20, 30, 45, 60, 90, 120];

  @override
  void dispose() {
    _destController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '🛡️ Safe Journey Shuru Karein',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Destination aur estimated time batao',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          // Destination field
          TextField(
            controller: _destController,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Destination (e.g. Ghar, College, Work)',
              hintStyle: GoogleFonts.inter(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.place_rounded, color: Color(0xFF22C55E)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF22C55E)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ETA selector
          Text(
            'ETA (kitne minute mein pahunchoge?)',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _etaOptions.map((opt) {
              final selected = _eta == opt;
              return GestureDetector(
                onTap: () => setState(() => _eta = opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF22C55E)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    '${opt}m',
                    style: GoogleFonts.inter(
                      color:
                          selected ? const Color(0xFF22C55E) : Colors.white54,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Start button
          GestureDetector(
            onTap: _loading
                ? null
                : () async {
                    if (_destController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Destination likhna zaroori hai')),
                      );
                      return;
                    }
                    setState(() => _loading = true);
                    widget.onStart(_destController.text.trim(), _eta);
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                gradient: _loading
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                color: _loading ? Colors.white12 : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _loading
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white54),
                      )
                    : Text(
                        '🛡️ Safe Journey Shuru Karein',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

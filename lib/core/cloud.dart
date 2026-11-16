import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'profile.dart';

/// Firebase over plain REST: anonymous sign-in plus a backup of the profile to
/// Firestore `users/{uid}`. Local storage stays the source of truth, so every
/// failure here is silent and retried on the next change.
// shortcut: REST instead of the Firebase SDKs, so no per-platform app registration
// is needed. Move to firebase_auth + cloud_firestore when Google sign-in or
// realtime listeners are needed.
const _apiKey = 'AIzaSyBgvCR_JDSXO2STpFOvQqOa2XXksVWkZEI'; // public client id, not a secret
const _project = 'investor-game-dev';

enum CloudState { idle, synced, offline }

class CloudStatus {
  const CloudStatus(this.state, [this.uid]);
  final CloudState state;
  final String? uid;
}

final cloudProvider = NotifierProvider<CloudSync, CloudStatus>(CloudSync.new);

class CloudSync extends Notifier<CloudStatus> {
  static const _kUid = 'cloud_uid', _kRefresh = 'cloud_refresh';
  String? _idToken;
  DateTime _expires = DateTime(0);
  Timer? _debounce;
  http.Client client = http.Client(); // replaced in tests

  @override
  CloudStatus build() => CloudStatus(CloudState.idle, ref.read(prefsProvider).getString(_kUid));

  /// Call once at startup. Pushes now and after every profile change.
  void start() {
    ref.listen(profileProvider, (_, p) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 4), () => push(p));
    });
    push(ref.read(profileProvider));
  }

  Future<Map<String, Object?>> _post(Uri url, Object body, {bool form = false}) async {
    final r = await client
        .post(url, headers: form ? null : {'content-type': 'application/json'}, body: form ? body : jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('auth ${r.statusCode}');
    return Map<String, Object?>.from(jsonDecode(r.body) as Map);
  }

  Future<String> _token() async {
    if (_idToken != null && DateTime.now().isBefore(_expires)) return _idToken!;
    final prefs = ref.read(prefsProvider);
    final refresh = prefs.getString(_kRefresh);
    final String id, uid, newRefresh;
    final int seconds;
    if (refresh == null) {
      final j = await _post(Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey'), {
        'returnSecureToken': true,
      });
      (id, uid, newRefresh) = (j['idToken']! as String, j['localId']! as String, j['refreshToken']! as String);
      seconds = int.parse(j['expiresIn']! as String);
    } else {
      final j = await _post(Uri.parse('https://securetoken.googleapis.com/v1/token?key=$_apiKey'), {
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
      }, form: true);
      (id, uid, newRefresh) = (j['id_token']! as String, j['user_id']! as String, j['refresh_token']! as String);
      seconds = int.parse(j['expires_in']! as String);
    }
    await prefs.setString(_kUid, uid);
    await prefs.setString(_kRefresh, newRefresh);
    _idToken = id;
    _expires = DateTime.now().add(Duration(seconds: seconds - 60));
    return id;
  }

  Future<void> push(Profile p) async {
    try {
      final token = await _token();
      final uid = ref.read(prefsProvider).getString(_kUid)!;
      final r = await client
          .patch(
            Uri.parse(
              'https://firestore.googleapis.com/v1/projects/$_project/databases/(default)/documents/users/$uid',
            ),
            headers: {'authorization': 'Bearer $token', 'content-type': 'application/json'},
            body: jsonEncode({'fields': profileFields(p, DateTime.now())}),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) throw Exception('firestore ${r.statusCode}');
      state = CloudStatus(CloudState.synced, uid);
    } catch (_) {
      state = CloudStatus(CloudState.offline, state.uid);
    }
  }
}

/// Firestore typed-value encoding of the profile. Must match firestore.rules.
Map<String, Object?> profileFields(Profile p, DateTime now) => {
  'name': {'stringValue': p.name.length > 20 ? p.name.substring(0, 20) : p.name},
  'xp': {'integerValue': '${p.xp}'},
  'coins': {'integerValue': '${p.coins}'},
  'streak': {'integerValue': '${p.streak}'},
  'level': {'integerValue': '${p.level}'},
  'blob': {'stringValue': jsonEncode(p.toJson())},
  'updatedAt': {'timestampValue': now.toUtc().toIso8601String()},
};

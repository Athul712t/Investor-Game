import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investor_game/core/cloud.dart';
import 'package:investor_game/core/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('signs in anonymously once, then backs up the profile with the id token', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calls = <http.Request>[];
    final client = MockClient((req) async {
      calls.add(req);
      if (req.url.host == 'identitytoolkit.googleapis.com') {
        return http.Response(
          jsonEncode({'idToken': 'tok', 'localId': 'u1', 'refreshToken': 'r1', 'expiresIn': '3600'}),
          200,
        );
      }
      return http.Response('{}', 200);
    });
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    final sync = c.read(cloudProvider.notifier)..client = client;
    await sync.push(c.read(profileProvider));
    await sync.push(c.read(profileProvider));

    expect(calls.where((r) => r.url.host == 'identitytoolkit.googleapis.com').length, 1);
    final write = calls.last;
    expect(write.method, 'PATCH');
    expect(write.url.path, endsWith('/documents/users/u1'));
    expect(write.headers['authorization'], 'Bearer tok');
    final fields = (jsonDecode(write.body) as Map)['fields'] as Map;
    // Keys must match the allow-list in firestore.rules.
    expect(fields.keys.toSet(), {'name', 'xp', 'coins', 'streak', 'level', 'blob', 'updatedAt'});
    expect(c.read(cloudProvider).state, CloudState.synced);
    expect(prefs.getString('cloud_refresh'), 'r1');
  });

  test('a network failure leaves the app offline, not broken', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    final sync = c.read(cloudProvider.notifier)..client = MockClient((_) async => http.Response('no', 500));
    await sync.push(c.read(profileProvider));
    expect(c.read(cloudProvider).state, CloudState.offline);
  });
}

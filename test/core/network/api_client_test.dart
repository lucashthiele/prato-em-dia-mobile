import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/core/network/api_failure.dart';

import 'fake_adapter.dart';

void main() {
  group('X-Client-Version', () {
    test('goes in every request, including login and refresh', () async {
      final adapter = FakeAdapter((_) => json(200, {}));
      final client = testClient(adapter);

      await client.dio.get<Object?>('/api/v1/me');
      await client.dio.post<Object?>('/api/v1/auth/login', data: {'a': 1});
      await client.dio.post<Object?>('/api/v1/auth/refresh');

      expect(adapter.requests, hasLength(3));
      for (final request in adapter.requests) {
        expect(request.headers['X-Client-Version'], 'android/0.1.0+1');
      }
    });
  });

  group('cookies', () {
    test('resends the session cookie set by the server', () async {
      final adapter = FakeAdapter((options) {
        if (options.path == '/api/v1/auth/login') {
          return json(
            200,
            {'expiresIn': 900, 'passwordChangeRequired': false},
            headers: {
              'set-cookie': ['access_token=abc; Path=/; HttpOnly'],
            },
          );
        }
        return json(200, {});
      });
      final client = testClient(adapter, jar: CookieJar());

      await client.dio.post<Object?>('/api/v1/auth/login');
      await client.dio.get<Object?>('/api/v1/me');

      expect(
        adapter.requests.last.headers['cookie'],
        contains('access_token=abc'),
      );
      expect(
        adapter.requests.last.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });

  group('refresh on 401', () {
    test('refreshes once, without body, and repeats the request', () async {
      var expired = true;
      final adapter = FakeAdapter((options) {
        if (options.path == '/api/v1/auth/refresh') {
          expired = false;
          return json(200, {'expiresIn': 900, 'passwordChangeRequired': false});
        }
        return expired
            ? errorEnvelope(401, 'AUTHENTICATION_REQUIRED')
            : json(200, {'ok': true});
      });
      final client = testClient(adapter);

      final response = await client.dio.get<Map<String, dynamic>>('/api/v1/me');

      expect(response.data, {'ok': true});
      expect(adapter.count('/api/v1/me'), 2);
      expect(adapter.count('/api/v1/auth/refresh'), 1);
      final refresh = adapter.requests.firstWhere(
        (r) => r.path == '/api/v1/auth/refresh',
      );
      expect(refresh.method, 'POST');
      expect(refresh.data, isNull);
    });

    test('parallel 401s share a single refresh in flight', () async {
      var expired = true;
      final adapter = FakeAdapter((options) {
        if (options.path == '/api/v1/auth/refresh') {
          expired = false;
          return json(200, {});
        }
        return expired
            ? errorEnvelope(401, 'AUTHENTICATION_REQUIRED')
            : json(200, {'path': options.path});
      });
      final client = testClient(adapter);

      final responses = await Future.wait([
        client.dio.get<Map<String, dynamic>>('/a'),
        client.dio.get<Map<String, dynamic>>('/b'),
        client.dio.get<Map<String, dynamic>>('/c'),
      ]);

      expect(responses.map((r) => r.data?['path']), ['/a', '/b', '/c']);
      expect(adapter.count('/api/v1/auth/refresh'), 1);
    });

    test('does not loop when the retried request is still 401', () async {
      final adapter = FakeAdapter((options) {
        if (options.path == '/api/v1/auth/refresh') return json(200, {});
        return errorEnvelope(401, 'AUTHENTICATION_REQUIRED');
      });
      final client = testClient(adapter);

      await expectLater(
        client.dio.get<Object?>('/api/v1/me'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.count('/api/v1/me'), 2);
      expect(adapter.count('/api/v1/auth/refresh'), 1);
    });

    test(
      'a rejected refresh ends the session and surfaces the error',
      () async {
        final adapter = FakeAdapter((options) {
          if (options.path == '/api/v1/auth/refresh') {
            return errorEnvelope(401, 'AUTH_REFRESH_TOKEN_INVALID');
          }
          return errorEnvelope(401, 'AUTHENTICATION_REQUIRED');
        });
        final client = testClient(adapter);
        var expiredEvents = 0;
        client.events.sessionExpired.listen((_) => expiredEvents++);

        await expectLater(
          client.dio.get<Object?>('/api/v1/me'),
          throwsA(isA<DioException>()),
        );
        await Future<void>.delayed(Duration.zero);

        expect(expiredEvents, 1);
        expect(adapter.count('/api/v1/me'), 1);
      },
    );

    test('an unreachable refresh keeps the session', () async {
      final adapter = FakeAdapter((options) {
        if (options.path == '/api/v1/auth/refresh') {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          );
        }
        return errorEnvelope(401, 'AUTHENTICATION_REQUIRED');
      });
      final client = testClient(adapter);
      var expiredEvents = 0;
      client.events.sessionExpired.listen((_) => expiredEvents++);

      await expectLater(
        client.dio.get<Object?>('/api/v1/me'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(expiredEvents, 0);
    });

    test('wrong credentials are not a reason to refresh', () async {
      final adapter = FakeAdapter(
        (_) => errorEnvelope(401, 'AUTH_INVALID_CREDENTIALS'),
      );
      final client = testClient(adapter);

      await expectLater(
        client.dio.patch<Object?>('/api/v1/me/password', data: {}),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        client.dio.post<Object?>('/api/v1/auth/login', data: {}),
        throwsA(isA<DioException>()),
      );

      expect(adapter.count('/api/v1/auth/refresh'), 0);
    });
  });

  group('426 CLIENT_OUTDATED', () {
    test('flags the app as outdated and keeps the error', () async {
      final adapter = FakeAdapter((_) => errorEnvelope(426, 'CLIENT_OUTDATED'));
      final client = testClient(adapter);
      expect(client.events.clientOutdated.value, isFalse);

      await expectLater(
        client.dio.get<Object?>('/api/v1/me'),
        throwsA(
          isA<DioException>().having(
            (e) => ApiFailure.fromDioException(e).code,
            'code',
            'CLIENT_OUTDATED',
          ),
        ),
      );

      expect(client.events.clientOutdated.value, isTrue);
      expect(adapter.count('/api/v1/auth/refresh'), 0);
    });
  });

  group('403 CONSENT_REQUIRED', () {
    test('asks for the consent once and repeats the blocked request', () async {
      var consented = false;
      final adapter = FakeAdapter(
        (options) => consented
            ? json(200, {'ok': true})
            : errorEnvelope(403, 'CONSENT_REQUIRED'),
      );
      final client = testClient(adapter);
      var asked = 0;
      client.events.consentHandler = () async {
        asked++;
        consented = true;
        return true;
      };

      final responses = await Future.wait([
        client.dio.get<Map<String, dynamic>>('/a'),
        client.dio.get<Map<String, dynamic>>('/b'),
      ]);

      expect(responses.every((r) => r.data?['ok'] == true), isTrue);
      expect(asked, 1);
      expect(adapter.count('/a'), 2);
    });

    test('keeps the error when the consent is not given', () async {
      final adapter = FakeAdapter(
        (_) => errorEnvelope(403, 'CONSENT_REQUIRED'),
      );
      final client = testClient(adapter);
      client.events.consentHandler = () async => false;

      await expectLater(
        client.dio.get<Object?>('/a'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.count('/a'), 1);
    });

    test('without a handler it is an ordinary error', () async {
      final adapter = FakeAdapter(
        (_) => errorEnvelope(403, 'CONSENT_REQUIRED'),
      );
      final client = testClient(adapter);

      await expectLater(
        client.dio.get<Object?>('/a'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.count('/a'), 1);
    });

    test('waits for a slow consent before repeating', () async {
      final gate = Completer<bool>();
      var consented = false;
      final adapter = FakeAdapter(
        (_) => consented
            ? json(200, {'ok': true})
            : errorEnvelope(403, 'CONSENT_REQUIRED'),
      );
      final client = testClient(adapter);
      client.events.consentHandler = () => gate.future;

      final pending = client.dio.get<Map<String, dynamic>>('/a');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(adapter.count('/a'), 1);
      consented = true;
      gate.complete(true);

      expect((await pending).data, {'ok': true});
    });
  });
}

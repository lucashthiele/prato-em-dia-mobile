import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/features/consent/data/consent_api.dart';
import 'package:prato_em_dia_mobile/features/consent/data/consent_repository_impl.dart';
import 'package:prato_em_dia_mobile/features/consent/domain/consent.dart';

Map<String, dynamic> _status({
  required String terms,
  required String privacy,
  bool termsAccepted = false,
  bool privacyAccepted = false,
}) => {
  'upToDate': termsAccepted && privacyAccepted,
  'documents': [
    {
      'documentType': 'TERMS_OF_USE',
      'currentVersion': terms,
      'accepted': termsAccepted,
    },
    {
      'documentType': 'PRIVACY_POLICY',
      'currentVersion': privacy,
      'accepted': privacyAccepted,
    },
  ],
};

DioException _mismatch() => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: 409,
    data: {
      'status': 409,
      'code': 'CONSENT_VERSION_MISMATCH',
      'message': 'x',
      'errors': [],
    },
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  test(
    'posts one acceptance per pending document with currentVersion',
    () async {
      final api = _FakeConsentApi([
        _status(terms: 'placeholder-1', privacy: 'placeholder-1'),
      ]);
      final result = await ConsentRepositoryImpl(api).acceptCurrent();

      expect(api.posts, [
        ('TERMS_OF_USE', 'placeholder-1'),
        ('PRIVACY_POLICY', 'placeholder-1'),
      ]);
      expect(result.upToDate, isTrue);
    },
  );

  test('skips documents that are already accepted', () async {
    final api = _FakeConsentApi([
      _status(terms: '1', privacy: '2', termsAccepted: true),
    ]);
    await ConsentRepositoryImpl(api).acceptCurrent();
    expect(api.posts, [('PRIVACY_POLICY', '2')]);
  });

  test('rereads the status and retries on CONSENT_VERSION_MISMATCH', () async {
    final api = _FakeConsentApi([
      _status(terms: '1', privacy: '1'),
      _status(terms: '2', privacy: '1'),
    ])..failFirstPostWith = _mismatch();

    await ConsentRepositoryImpl(api).acceptCurrent();

    expect(api.statusCalls, 2);
    expect(api.posts, [('TERMS_OF_USE', '2'), ('PRIVACY_POLICY', '1')]);
  });

  test('gives up after repeated mismatches with a pt-BR message', () {
    final api = _FakeConsentApi([_status(terms: '1', privacy: '1')])
      ..alwaysMismatch = true;
    expect(
      ConsentRepositoryImpl(api).acceptCurrent(),
      throwsA(
        isA<ConsentFailure>().having(
          (f) => f.message,
          'message',
          contains('termos foram atualizados'),
        ),
      ),
    );
  });
}

class _FakeConsentApi implements ConsentRemoteDataSource {
  _FakeConsentApi(this._statuses);

  final List<Map<String, dynamic>> _statuses;
  final posts = <(String, String)>[];
  int statusCalls = 0;
  DioException? failFirstPostWith;
  bool alwaysMismatch = false;
  final _accepted = <String>{};

  Map<String, dynamic> get _current =>
      _statuses[(statusCalls - 1).clamp(0, _statuses.length - 1)];

  Map<String, dynamic> _withAccepted() {
    final documents = [
      for (final d in _current['documents'] as List)
        {
          ...(d as Map<String, dynamic>),
          'accepted':
              d['accepted'] == true || _accepted.contains(d['documentType']),
        },
    ];
    return {
      'upToDate': documents.every((d) => d['accepted'] == true),
      'documents': documents,
    };
  }

  @override
  Future<Map<String, dynamic>> status() async {
    statusCalls++;
    return _withAccepted();
  }

  @override
  Future<Map<String, dynamic>> accept({
    required String documentType,
    required String version,
  }) async {
    if (alwaysMismatch) throw _mismatch();
    if (failFirstPostWith != null) {
      final error = failFirstPostWith!;
      failFirstPostWith = null;
      throw error;
    }
    posts.add((documentType, version));
    _accepted.add(documentType);
    return _withAccepted();
  }
}

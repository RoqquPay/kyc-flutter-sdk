import 'package:flutter_test/flutter_test.dart';
import 'package:roqqu_kyc/roqqu_kyc.dart';
import 'mock_kyc_api_client.dart';

void main() {
  group('KycApiClient', () {
    late KycApiClient client;

    setUp(() {
      client = MockKycApiClient();
    });

    test('createSession returns valid session', () async {
      final session = await client.createSession(
          email: 'test@example.com', userId: 'user1');

      expect(session.sessionId, isNotEmpty);
      expect(session.token, isNotEmpty);
      expect(session.isValid, true);
    });

    test('verifySession returns true for valid session', () async {
      final session = await client.createSession(
          email: 'test@example.com', userId: 'user1');
      final isValid = await client.verifySession(session);

      expect(isValid, true);
    });
  });
}

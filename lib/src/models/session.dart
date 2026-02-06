import 'package:equatable/equatable.dart';

class KycSession extends Equatable {
  const KycSession({
    required this.sessionId,
    required this.token,
    required this.expiry,
  });

  final String sessionId;
  final String token;
  final DateTime expiry;

  bool get isValid => DateTime.now().isBefore(expiry);

  @override
  List<Object> get props => [sessionId, token, expiry];
}

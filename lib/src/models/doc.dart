import 'package:equatable/equatable.dart';

class KycDoc extends Equatable {
  const KycDoc({required this.title, required this.key});

  factory KycDoc.fromJson(Map<String, dynamic> map) {
    return KycDoc(
      title: map['title'] as String,
      key: map['key'] as String,
    );
  }

  final String title;
  final String key;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'key': key, 'title': title};
  }

  @override
  String toString() => 'KycDoc(title: $title, key: $key)';

  @override
  List<Object> get props => [title, key];
}

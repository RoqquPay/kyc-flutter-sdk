import 'dart:convert';

import 'package:equatable/equatable.dart';

class KycRequiredMetaData extends Equatable {
  const KycRequiredMetaData({
    required this.required,
    this.metadata,
  });

  factory KycRequiredMetaData.fromJson(Map<String, dynamic> map) {
    return KycRequiredMetaData(
      required: List<String>.from(map['required'] as List<String>),
      metadata: map['metadata'] != null
          ? KycMetadata.fromJson(map['metadata'] as Map<String, dynamic>)
          : null,
    );
  }

  final List<String> required;
  final KycMetadata? metadata;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'required': required,
      'metadata': metadata?.toJson(),
    };
  }

  @override
  List<Object?> get props => [required, metadata];
}

class KycMetadata extends Equatable {
  const KycMetadata({this.identifier, this.tier});

  factory KycMetadata.fromJson(Map<String, dynamic> map) {
    return KycMetadata(
      identifier: map['identifier'] as String?,
      tier: map['tier'] as String?,
    );
  }

  final String? identifier;
  final String? tier;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'identifier': identifier,
      'tier': tier,
    };
  }

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [identifier, tier];
}

Map<String, dynamic> extractQueryParams(String url) {
  final Uri uri = Uri.parse(url);
  final Map<String, dynamic> data = {};

  final requiredParams = uri.queryParameters['required'];
  if (requiredParams != null) data['required'] = requiredParams.split(',');

  final metaDataParams = uri.queryParameters['metadata'];
  if (metaDataParams != null) data['metadata'] = jsonDecode(metaDataParams);

  return data;
}

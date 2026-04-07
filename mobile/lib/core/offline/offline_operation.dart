import 'dart:convert';

class OfflineOperation {
  const OfflineOperation({
    required this.id,
    required this.module,
    required this.method,
    required this.path,
    required this.payload,
    required this.createdAt,
    this.status = 'pending',
    this.errorMessage,
  });

  final String id;
  final String module;
  final String method;
  final String path;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String status;
  final String? errorMessage;

  OfflineOperation copyWith({
    String? status,
    String? errorMessage,
  }) {
    return OfflineOperation(
      id: id,
      module: module,
      method: method,
      path: path,
      payload: payload,
      createdAt: createdAt,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'module': module,
      'method': method,
      'path': path,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'status': status,
      'error_message': errorMessage,
    };
  }

  factory OfflineOperation.fromMap(Map<String, dynamic> map) {
    final rawPayload = map['payload'];
    final payload = rawPayload is String
        ? Map<String, dynamic>.from(jsonDecode(rawPayload) as Map)
        : Map<String, dynamic>.from(rawPayload as Map);

    return OfflineOperation(
      id: map['id'] as String,
      module: map['module'] as String,
      method: map['method'] as String,
      path: map['path'] as String,
      payload: payload,
      createdAt: DateTime.parse(map['created_at'] as String),
      status: map['status'] as String? ?? 'pending',
      errorMessage: map['error_message'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory OfflineOperation.fromJson(String source) =>
      OfflineOperation.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

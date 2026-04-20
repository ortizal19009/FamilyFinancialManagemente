import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../storage/token_storage.dart';

class ApiClient {
  ApiClient({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage();

  final TokenStorage _tokenStorage;

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await _tokenStorage.getToken();
      if (token != null && token.isNotEmpty && !token.startsWith('local-')) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> get(String path, {bool auth = true}) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(auth: auth),
    );
    return _decode(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(auth: auth),
    );
    return _decode(response);
  }

  Future<dynamic> postMultipart(
    String path, {
    required Map<String, dynamic> fields,
    String? fileField,
    String? filePath,
    bool auth = true,
  }) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$path'),
    );

    final headers = await _headers(auth: auth);
    headers.remove('Content-Type');
    request.headers.addAll(headers);
    request.fields['payload'] = jsonEncode(fields);

    if (fileField != null && filePath != null && filePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final data = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    final message = data is Map<String, dynamic> ? data['msg']?.toString() : null;
    throw Exception(message ?? 'Error de conexion con el backend');
  }
}

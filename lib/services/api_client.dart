import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_client.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, Uri? base})
    : _client = client ?? createHttpClient(),
      _base = base ?? Uri.base;
  final http.Client _client;
  final Uri _base;

  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(method, _base.resolve(path));
    request.headers['accept'] = 'application/json';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 8)),
      ).timeout(const Duration(seconds: 8));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException(
          'The save service returned an unexpected response.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'];
        throw ApiException(
          error is String
              ? error.replaceAll('_', ' ')
              : 'The save service is unavailable.',
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Cloud service unavailable. Local play is ready.',
      );
    }
  }

  void close() => _client.close();
}

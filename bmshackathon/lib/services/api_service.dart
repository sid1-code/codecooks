import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class ApiService {
  ApiService({String? baseUrl, String? chatPath, http.Client? client, TokenService? tokenService})
      : baseUrl = _resolveBaseUrl(baseUrl),
        chatPath = _resolveChatPath(chatPath),
        _client = client ?? http.Client(),
        _tokenService = tokenService ?? TokenService() {
    // Debug: log resolved endpoints to verify dart-defines in web builds
    // ignore: avoid_print
    print('[ApiService] baseUrl=' + this.baseUrl + ' chatPath=' + this.chatPath);
  }

  /// Base URL for the backend API. Can be provided to the constructor, or
  /// supplied at build/run time via: --dart-define=API_BASE_URL=https://api.example.com
  final String baseUrl;
  // Path to AI chat endpoint, configurable at build/run time via --dart-define=AI_CHAT_PATH=/your/path
  final String chatPath;
  final http.Client _client;
  final TokenService _tokenService;

  // Resolve base URL with priority: explicit override > URL query (?apiBaseUrl=...) > dart-define > default
  static String _resolveBaseUrl(String? override) {
    if (override != null && override.isNotEmpty) return override;
    final qp = Uri.base.queryParameters;
    final fromUrl = qp['apiBaseUrl'];
    if (fromUrl != null && fromUrl.isNotEmpty) return fromUrl;
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8011');
    return fromEnv;
  }

  // Resolve chat path with priority: explicit override > URL query (?chatPath=...) > dart-define > default
  static String _resolveChatPath(String? override) {
    if (override != null && override.isNotEmpty) return override;
    final qp = Uri.base.queryParameters;
    final fromUrl = qp['chatPath'];
    if (fromUrl != null && fromUrl.isNotEmpty) return fromUrl;
    const fromEnv = String.fromEnvironment('AI_CHAT_PATH', defaultValue: '/ai/chat');
    return fromEnv;
  }

  Uri _u(String path, [Map<String, dynamic>? query]) {
    final raw = Uri.parse(baseUrl + path).replace(
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
    // Enforce HTTPS for non-local hosts, but allow common local/LAN ranges
    final host = raw.host;
    final isLocal = host == '127.0.0.1' || host == 'localhost' ||
        host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        // 172.16.0.0 – 172.31.255.255
        RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\..*').hasMatch(host);
    if (!isLocal && raw.scheme != 'https') {
      return raw.replace(scheme: 'https');
    }
    return raw;
  }

  Future<http.Response> _retryRequest(Future<http.Response> Function() fn, {int attempts = 3}) async {
    int tries = 0;
    late http.Response res;
    while (true) {
      tries++;
      try {
        res = await fn();
        return res;
      } catch (_) {
        if (tries >= attempts) rethrow;
        await Future.delayed(Duration(milliseconds: 300 * tries));
      }
    }
  }

  Future<Map<String, String>> _headers({Map<String, String>? extra, bool form = false}) async {
    final token = await _tokenService.getToken();
    final base = <String, String>{
      'Content-Type': form ? 'application/x-www-form-urlencoded' : 'application/json',
      'Accept-Encoding': 'gzip',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    if (extra != null) base.addAll(extra);
    return base;
  }

  Future<String> aiChat({required List<Map<String, String>> history, String language = 'en'}) async {
    final uri = _u(chatPath);
    final headers = await _headers();
    final res = await _retryRequest(() => _client.post(
          uri,
          headers: headers,
          body: jsonEncode({
            'history': history,
            'language': language,
          }),
        ));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['reply'] as String?) ?? '';
    }
    throw Exception('AI chat failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, String>> triage({required String symptom}) async {
    final uri = _u('/triage');
    final headers = await _headers();
    final res = await _retryRequest(() => _client.post(
          uri,
          headers: headers,
          body: jsonEncode({'symptom': symptom}),
        ));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return {
        'status': (data['status'] as String?) ?? 'SELF-CARE',
        'recommendation': (data['recommendation'] as String?) ?? '',
      };
    }
    throw Exception('Triage failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> aiTriageAdvice({
    required String symptom,
    int? age,
    String? sex,
    bool? pregnant,
    List<String>? chronicConditions,
    String? location,
    String? language,
  }) async {
    final uri = _u('/ai/triage-advice');
    final headers = await _headers();
    final res = await _retryRequest(() => _client.post(
          uri,
          headers: headers,
          body: jsonEncode({
            'symptom': symptom,
            'age': age,
            'sex': sex,
            'pregnant': pregnant,
            'chronic_conditions': chronicConditions,
            'location': location,
            'language': language,
          }),
        ));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return {
        'advice': (data['advice'] as String?) ?? '',
        'confidence': (data['confidence'] as num?)?.toDouble(),
      };
    }
    throw Exception('AI triage advice failed: ${res.statusCode} ${res.body}');
  }

  Future<List<Map<String, dynamic>>> servicesNearby({
    required double lat,
    required double lon,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    final uri = _u('/services/nearby', {
      'lat': lat,
      'lon': lon,
      'radius_km': radiusKm,
      'limit': limit,
    });
    final res = await _retryRequest(() => _client.get(uri));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Services nearby failed: ${res.statusCode} ${res.body}');
  }

  Future<String> translate({required String text, required String targetLanguage}) async {
    final uri = _u('/translate');
    final headers = await _headers(form: true);
    final res = await _retryRequest(() => _client.post(
          uri,
          headers: headers,
          body: {'text': text, 'target_language': targetLanguage},
        ));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['text'] as String? ?? text);
    }
    throw Exception('Translate failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> getConfig() async {
    final uri = _u('/config');
    final res = await _retryRequest(() => _client.get(uri));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Get config failed: ${res.statusCode} ${res.body}');
  }

  /// Lightweight reachability check that does not depend on specific endpoints.
  /// Returns true if the server responds to a GET request (even 404),
  /// and false/throws only on network/CORS failures.
  Future<bool> ping() async {
    try {
      final uri = _u('/');
      final res = await _retryRequest(() => _client.get(uri));
      // Any HTTP response means the host is reachable
      return res.statusCode > 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> shareReferral({
    required String tenantId,
    required String summary,
    required String riskLevel,
    required DateTime timestamp,
    String? userName,
    String? userContact,
    bool anonymous = false,
  }) async {
    final uri = _u('/referrals');
    final headers = await _headers();
    final res = await _retryRequest(() => _client.post(
          uri,
          headers: headers,
          body: jsonEncode({
            'tenant_id': tenantId,
            'summary': summary,
            'risk_level': riskLevel,
            'timestamp': timestamp.toIso8601String(),
            if (!anonymous) 'user': {'name': userName, 'contact': userContact},
          }),
        ));
    return res.statusCode >= 200 && res.statusCode < 300;
  }
}

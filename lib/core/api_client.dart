import 'package:dio/dio.dart';
import 'auth_storage.dart';

class ApiClient {
  static Dio? _dio;

  static Future<Dio> get() async {
    final baseUrl = await AuthStorage.getBaseUrl();
    final token = await AuthStorage.getToken();

    _dio = Dio(BaseOptions(
      baseUrl: '$baseUrl/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ));

    _dio!.interceptors.add(InterceptorsWrapper(
      onError: (e, handler) async {
        if (e.response?.statusCode == 401) {
          await AuthStorage.clear();
        }
        handler.next(e);
      },
    ));

    return _dio!;
  }

  static void reset() => _dio = null;

  static String errorMessage(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        final d = data['detail'];
        if (d is List) return d.map((x) => x['msg'] ?? x.toString()).join('; ');
        return d.toString();
      }
      if (e.response?.statusCode == 429) return 'Muitas tentativas. Aguarde 1 minuto.';
      if (e.type == DioExceptionType.connectionTimeout) return 'Servidor não respondeu. Verifique a URL.';
      if (e.type == DioExceptionType.connectionError) return 'Sem conexão com o servidor.';
    }
    return 'Erro inesperado.';
  }
}

import 'package:dio/dio.dart';

import '../core/config.dart';
import 'models/questionario.dart';
import 'models/resultado.dart';

/// Erro com mensagem pronta para mostrar ao usuário.
class ErroApi implements Exception {
  ErroApi(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Único ponto do app que conversa com a API do Equilibra.
class ApiCliente {
  ApiCliente({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: Config.apiUrl,
              connectTimeout: const Duration(seconds: 15),
              // O Container Apps pode estar "dormindo" (escala a zero): a 1ª chamada demora mais.
              receiveTimeout: const Duration(seconds: 30),
              headers: {'X-API-Key': Config.apiKey},
            ));

  final Dio _dio;

  Future<void> registrarUsuario(String usuarioId) => _executar(() => _dio.post(
        '/usuarios',
        data: {'id': usuarioId, 'consentimento': true, 'versao_termo': Config.versaoTermo},
      ));

  Future<Resultado> prever(String usuarioId, Questionario respostas) async {
    final r = await _executar(() => _dio.post(
          '/predicoes',
          data: {'usuario_id': usuarioId, 'respostas': respostas.toJson()},
        ));
    return Resultado.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<AvaliacaoResumo>> historico(String usuarioId) async {
    final r = await _executar(() => _dio.get('/usuarios/$usuarioId/avaliacoes'));
    return (r.data as List)
        .map((e) => AvaliacaoResumo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> apagarDados(String usuarioId) async {
    try {
      await _dio.delete('/usuarios/$usuarioId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return; // já não existia
      throw _traduzir(e);
    }
  }

  Future<Response<dynamic>> _executar(Future<Response<dynamic>> Function() chamada) async {
    try {
      return await chamada();
    } on DioException catch (e) {
      throw _traduzir(e);
    }
  }

  ErroApi _traduzir(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) {
      return ErroApi('Sem conexão com o servidor. Verifique sua internet e tente de novo.');
    }
    if (status == 401) return ErroApi('Acesso não autorizado à API.');
    if (status == 404) return ErroApi('Cadastro não encontrado. Reabra o app e aceite o termo.');
    if (status == 422) return ErroApi('Alguma resposta está fora do esperado.');
    return ErroApi('Erro no servidor ($status). Tente mais tarde.');
  }
}

import 'package:dio/dio.dart';

import '../core/config.dart';
import 'models/questionario.dart';
import 'models/resultado.dart';
import 'models/sessao.dart';

/// Erro com mensagem pronta para mostrar ao usuário.
class ErroApi implements Exception {
  ErroApi(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// A sessão de login venceu ou não vale para estes dados: o usuário precisa entrar de novo.
class ErroSessao extends ErroApi {
  ErroSessao(super.mensagem);
}

/// Único ponto do app que conversa com a API do Equilibra.
class ApiCliente {
  /// [token]: token da sessão de login; quando presente, vai em todas as chamadas.
  ApiCliente({Dio? dio, String? token})
      : _token = token,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: Config.apiUrl,
              connectTimeout: const Duration(seconds: 15),
              // O Container Apps pode estar "dormindo" (escala a zero): a 1ª chamada demora mais.
              receiveTimeout: const Duration(seconds: 30),
              headers: {'X-API-Key': Config.apiKey},
            ));

  final Dio _dio;
  final String? _token;

  Options get _opcoes => Options(headers: {if (_token != null) 'Authorization': 'Bearer $_token'});

  Future<void> registrarUsuario(String usuarioId) => _executar(() => _dio.post(
        '/usuarios',
        data: {'id': usuarioId, 'consentimento': true, 'versao_termo': Config.versaoTermo},
      ));

  Future<Resultado> prever(String usuarioId, Questionario respostas) async {
    final r = await _executar(() => _dio.post(
          '/predicoes',
          data: {'usuario_id': usuarioId, 'respostas': respostas.toJson()},
          options: _opcoes,
        ));
    return Resultado.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<AvaliacaoResumo>> historico(String usuarioId) async {
    final r = await _executar(() => _dio.get('/usuarios/$usuarioId/avaliacoes', options: _opcoes));
    return (r.data as List)
        .map((e) => AvaliacaoResumo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> apagarDados(String usuarioId) async {
    try {
      await _dio.delete('/usuarios/$usuarioId', options: _opcoes);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return; // já não existia
      throw _traduzir(e);
    }
  }

  /// Transforma o usuário anônimo [usuarioId] numa conta. O histórico dele continua o mesmo.
  Future<Sessao> cadastrar({
    required String usuarioId,
    required String email,
    required String senha,
  }) async {
    final r = await _executar(() => _dio.post('/auth/cadastro', data: {
          'usuario_id': usuarioId,
          'email': email,
          'senha': senha,
          'consentimento': true,
          'versao_termo': Config.versaoTermoConta,
        }));
    return Sessao.fromJson(r.data as Map<String, dynamic>);
  }

  /// Entra na conta. As avaliações do [usuarioIdAnonimo] deste aparelho são unidas a ela.
  Future<Sessao> entrar({
    required String email,
    required String senha,
    String? usuarioIdAnonimo,
  }) async {
    final r = await _executar(() => _dio.post('/auth/login', data: {
          'email': email,
          'senha': senha,
          if (usuarioIdAnonimo != null) 'usuario_id_anonimo': usuarioIdAnonimo,
        }));
    return Sessao.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Response<dynamic>> _executar(Future<Response<dynamic>> Function() chamada) async {
    try {
      return await chamada();
    } on DioException catch (e) {
      throw _traduzir(e);
    }
  }

  ErroApi _traduzir(DioException e) {
    final resposta = e.response;
    final status = resposta?.statusCode;
    if (resposta == null || status == null) {
      return ErroApi('Sem conexão com o servidor. Verifique sua internet e tente de novo.');
    }
    // As mensagens de conta da API já vêm prontas em português no campo "detail".
    final dados = resposta.data;
    final detalhe = dados is Map && dados['detail'] is String ? dados['detail'] as String : null;
    final pedeLogin =
        resposta.headers.value('www-authenticate')?.toLowerCase().startsWith('bearer') ?? false;

    if (status == 401 && pedeLogin) return ErroSessao(detalhe ?? 'Sua sessão expirou. Entre de novo.');
    if (status == 403) return ErroSessao('Esta sessão não tem acesso a estes dados. Entre de novo.');
    if (status == 401) return ErroApi(detalhe ?? 'Acesso não autorizado à API.');
    if (status == 404) return ErroApi('Cadastro não encontrado. Reabra o app e aceite o termo.');
    if (status == 409 || status == 429) return ErroApi(detalhe ?? 'Não foi possível concluir. Tente de novo.');
    if (status == 422) return ErroApi('Alguma resposta está fora do esperado.');
    return ErroApi('Erro no servidor ($status). Tente mais tarde.');
  }
}

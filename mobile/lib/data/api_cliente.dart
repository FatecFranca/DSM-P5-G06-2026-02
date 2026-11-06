import 'package:dio/dio.dart';

import '../core/config.dart';
import 'models/painel.dart';
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

/// O servidor não conhece o id deste aparelho (banco recriado, dados que sobraram do modo demo...).
/// É preciso aceitar o termo de novo para registrar o aparelho.
class ErroCadastroAusente extends ErroApi {
  ErroCadastroAusente()
      : super('Seu cadastro não foi encontrado no servidor. Aceite o termo de novo para continuar.');
}

/// Único ponto do app que conversa com a API do Equilibra.
class ApiCliente {
  /// [token]: token da sessão de login; quando presente, vai em todas as chamadas.
  ApiCliente({Dio? dio, String? token})
      : _token = token,
        _dio = dio ?? criarDio();

  /// Conexão HTTP com a API, já com o endereço e a chave do app.
  static Dio criarDio() => Dio(BaseOptions(
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

  /// Média de todas as respostas e dicas. Exclusivo de quem tem conta (exige o token).
  Future<Painel> painel(String usuarioId) async {
    final r = await _executar(() => _dio.get('/usuarios/$usuarioId/painel', options: _opcoes));
    return Painel.fromJson(r.data as Map<String, dynamic>);
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
    return _chamarConta('/auth/cadastro', {
      'usuario_id': usuarioId,
      'email': email,
      'senha': senha,
      'consentimento': true,
      'versao_termo': Config.versaoTermoConta,
    });
  }

  /// Entra na conta. As avaliações do [usuarioIdAnonimo] deste aparelho são unidas a ela.
  Future<Sessao> entrar({
    required String email,
    required String senha,
    String? usuarioIdAnonimo,
  }) async {
    return _chamarConta('/auth/login', {
      'email': email,
      'senha': senha,
      if (usuarioIdAnonimo != null) 'usuario_id_anonimo': usuarioIdAnonimo,
    });
  }

  /// Cadastro e login. A API recusa com 422 alguns e-mails que parecem válidos no celular
  /// (ex.: ana@empresa.local); aqui a mensagem genérica não faria sentido para o usuário.
  Future<Sessao> _chamarConta(String rota, Map<String, dynamic> dados) async {
    try {
      final r = await _dio.post(rota, data: dados);
      return Sessao.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        throw ErroApi('Confira o e-mail e a senha: algum deles não é válido.');
      }
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
    // Só o 404 da nossa API ("Usuário não encontrado...") significa aparelho desconhecido. Um 404
    // genérico ("Not Found", ex.: API_URL errada) não pode apagar os dados locais.
    if (status == 404 && (detalhe?.startsWith('Usuário não encontrado') ?? false)) {
      return ErroCadastroAusente();
    }
    if (status == 404) return ErroApi('Serviço não encontrado. Verifique o endereço da API.');
    if (status == 409 || status == 429) return ErroApi(detalhe ?? 'Não foi possível concluir. Tente de novo.');
    if (status == 422) return ErroApi('Alguma resposta está fora do esperado.');
    return ErroApi('Erro no servidor ($status). Tente mais tarde.');
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../data/api_cliente.dart';
import '../data/api_demo.dart';
import '../data/armazenamento_local.dart';
import '../data/models/painel.dart';
import '../data/models/resultado.dart';
import '../data/models/sessao.dart';
import '../data/sessao_armazenamento.dart';

/// Substituído em main.dart pela instância real (carregada antes do app abrir).
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider deve ser sobrescrito em main.dart'),
);

final armazenamentoProvider = Provider<ArmazenamentoLocal>(
  (ref) => ArmazenamentoLocal(ref.watch(prefsProvider)),
);

final sessaoArmazenamentoProvider = Provider<SessaoArmazenamento>((ref) => SessaoArmazenamento());

/// Sessão lida do armazenamento seguro antes do app abrir (main.dart). null = sem login.
final sessaoInicialProvider = Provider<Sessao?>((ref) => null);

/// Sessão de login atual. null = usuário anônimo (ou sessão expirada).
final sessaoProvider = NotifierProvider<SessaoControle, Sessao?>(SessaoControle.new);

/// Conexão HTTP única do app. Nos testes é trocada por uma que não usa a rede,
/// mantendo reais os provedores abaixo dela.
final dioProvider = Provider<Dio>((ref) => ApiCliente.criarDio());

/// API sem token, para cadastro e login. Não depende da sessão: por isso o SessaoControle
/// pode usá-la sem criar um ciclo (sessão → API → sessão).
final apiPublicaProvider = Provider<ApiCliente>(
  (ref) => Config.modoDemo ? ApiDemo(ref.watch(prefsProvider)) : ApiCliente(dio: ref.watch(dioProvider)),
);

/// API com o token da sessão atual, para os dados do usuário. É recriada quando a sessão muda.
/// Não use dentro do SessaoControle (ciclo); lá vale o apiPublicaProvider.
final apiProvider = Provider<ApiCliente>(
  (ref) => Config.modoDemo
      ? ApiDemo(ref.watch(prefsProvider))
      : ApiCliente(dio: ref.watch(dioProvider), token: ref.watch(sessaoProvider)?.token),
);

/// Histórico do usuário. Use ref.invalidate(historicoProvider) para recarregar.
final historicoProvider = FutureProvider.autoDispose<List<AvaliacaoResumo>>((ref) {
  final api = ref.watch(apiProvider);
  return api.historico(ref.read(armazenamentoProvider).usuarioId);
});

/// Dados do painel da tela Home, exclusivo de quem tem conta.
/// Use ref.invalidate(painelProvider) depois de uma nova avaliação.
final painelProvider = FutureProvider.autoDispose<Painel>((ref) {
  final api = ref.watch(apiProvider);
  final sessao = ref.watch(sessaoProvider);
  // Ao sair da conta, a Home fica na tela por mais um instante e o painel recarrega. Sem sessão, a
  // API não é chamada: isso criaria um id novo e o enviaria antes de o usuário aceitar o termo de novo.
  if (sessao == null) throw ErroSessao('Entre na sua conta para ver o painel.');
  return api.painel(sessao.usuarioId);
});

class SessaoControle extends Notifier<Sessao?> {
  @override
  Sessao? build() => ref.read(sessaoInicialProvider);

  /// Cria a conta a partir do usuário anônimo deste aparelho (o histórico continua).
  Future<void> cadastrar({required String email, required String senha}) async {
    final usuarioId = ref.read(armazenamentoProvider).usuarioId;
    final sessao =
        await ref.read(apiPublicaProvider).cadastrar(usuarioId: usuarioId, email: email, senha: senha);
    await _iniciar(sessao);
  }

  /// Entra numa conta; as avaliações anônimas deste aparelho passam para ela.
  Future<void> entrar({required String email, required String senha}) async {
    final usuarioIdAnonimo = ref.read(armazenamentoProvider).usuarioId;
    final sessao = await ref
        .read(apiPublicaProvider)
        .entrar(email: email, senha: senha, usuarioIdAnonimo: usuarioIdAnonimo);
    await _iniciar(sessao);
  }

  /// Sai da conta: apaga o token e os dados locais. O aparelho volta a ser anônimo
  /// e o termo é pedido de novo (um novo id anônimo precisa ser registrado na API).
  Future<void> sair() async {
    await ref.read(sessaoArmazenamentoProvider).apagar();
    await ref.read(armazenamentoProvider).limpar();
    state = null;
  }

  Future<void> _iniciar(Sessao sessao) async {
    await ref.read(armazenamentoProvider).vincularConta(usuarioId: sessao.usuarioId, email: sessao.email);
    await ref.read(sessaoArmazenamentoProvider).salvar(sessao);
    state = sessao;
  }
}

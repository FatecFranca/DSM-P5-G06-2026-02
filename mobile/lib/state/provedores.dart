import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../data/api_cliente.dart';
import '../data/api_demo.dart';
import '../data/armazenamento_local.dart';
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

/// A API é recriada quando a sessão muda, para enviar o token certo.
final apiProvider = Provider<ApiCliente>(
  (ref) => Config.modoDemo
      ? ApiDemo(ref.watch(prefsProvider))
      : ApiCliente(token: ref.watch(sessaoProvider)?.token),
);

/// Histórico do usuário. Use ref.invalidate(historicoProvider) para recarregar.
final historicoProvider = FutureProvider.autoDispose<List<AvaliacaoResumo>>((ref) {
  final api = ref.watch(apiProvider);
  return api.historico(ref.read(armazenamentoProvider).usuarioId);
});

class SessaoControle extends Notifier<Sessao?> {
  @override
  Sessao? build() => ref.read(sessaoInicialProvider);

  /// Cria a conta a partir do usuário anônimo deste aparelho (o histórico continua).
  Future<void> cadastrar({required String email, required String senha}) async {
    final usuarioId = ref.read(armazenamentoProvider).usuarioId;
    final sessao = await ref.read(apiProvider).cadastrar(usuarioId: usuarioId, email: email, senha: senha);
    await _iniciar(sessao);
  }

  /// Entra numa conta; as avaliações anônimas deste aparelho passam para ela.
  Future<void> entrar({required String email, required String senha}) async {
    final usuarioIdAnonimo = ref.read(armazenamentoProvider).usuarioId;
    final sessao = await ref
        .read(apiProvider)
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

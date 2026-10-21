import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../data/api_cliente.dart';
import '../data/api_demo.dart';
import '../data/armazenamento_local.dart';
import '../data/models/resultado.dart';

/// Substituído em main.dart pela instância real (carregada antes do app abrir).
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider deve ser sobrescrito em main.dart'),
);

final armazenamentoProvider = Provider<ArmazenamentoLocal>(
  (ref) => ArmazenamentoLocal(ref.watch(prefsProvider)),
);

final apiProvider = Provider<ApiCliente>(
  (ref) => Config.modoDemo ? ApiDemo(ref.watch(prefsProvider)) : ApiCliente(),
);

/// Histórico do usuário. Use ref.invalidate(historicoProvider) para recarregar.
final historicoProvider = FutureProvider.autoDispose<List<AvaliacaoResumo>>((ref) {
  final id = ref.watch(armazenamentoProvider).usuarioId;
  return ref.watch(apiProvider).historico(id);
});

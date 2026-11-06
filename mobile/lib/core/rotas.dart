import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/resultado.dart';
import '../screens/consentimento_tela.dart';
import '../screens/entrar_tela.dart';
import '../screens/historico_tela.dart';
import '../screens/home_tela.dart';
import '../screens/inicio_tela.dart';
import '../screens/questionario_tela.dart';
import '../screens/resultado_tela.dart';
import '../state/provedores.dart';

final rotasProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final local = state.matchedLocation;
      // Sem o aceite do termo (LGPD), o usuário só vê a tela de consentimento.
      if (!ref.read(armazenamentoProvider).consentiu) {
        return local == '/consentimento' ? null : '/consentimento';
      }
      if (local == '/consentimento') return '/';

      // Quem entrou numa conta tem a Home com o painel; o painel é exclusivo de quem tem conta.
      final logado = ref.read(sessaoProvider) != null;
      if (logado && local == '/') return '/home';
      if (!logado && local == '/home') return '/entrar?modo=entrar';
      return null;
    },
    routes: [
      GoRoute(path: '/consentimento', builder: (context, state) => const ConsentimentoTela()),
      GoRoute(path: '/', builder: (context, state) => const InicioTela()),
      GoRoute(path: '/home', builder: (context, state) => const HomeTela()),
      GoRoute(path: '/questionario', builder: (context, state) => const QuestionarioTela()),
      GoRoute(
        path: '/resultado',
        builder: (context, state) => ResultadoTela(
          resultado: state.extra! as Resultado,
          convidarParaConta: ref.read(sessaoProvider) == null,
        ),
      ),
      GoRoute(path: '/historico', builder: (context, state) => const HistoricoTela()),
      GoRoute(
        path: '/entrar',
        builder: (context, state) => EntrarTela(
          modoInicial:
              state.uri.queryParameters['modo'] == 'entrar' ? ModoConta.entrar : ModoConta.criar,
        ),
      ),
    ],
  );
});

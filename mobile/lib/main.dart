import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/rotas.dart';
import 'core/tema.dart';
import 'data/sessao_armazenamento.dart';
import 'state/provedores.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final sessao = await SessaoArmazenamento().carregar();
  runApp(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      sessaoInicialProvider.overrideWithValue(sessao),
    ],
    child: const EquilibraApp(),
  ));
}

class EquilibraApp extends ConsumerWidget {
  const EquilibraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Equilibra',
      debugShowCheckedModeBanner: false,
      theme: Tema.claro(),
      darkTheme: Tema.escuro(),
      routerConfig: ref.watch(rotasProvider),
    );
  }
}

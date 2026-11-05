import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/api_cliente.dart';
import '../state/provedores.dart';
import 'mensagens.dart';

/// Resposta ao ErroCadastroAusente: o servidor não reconhece este aparelho.
/// Limpa os dados locais e volta ao termo de consentimento, que registra o aparelho de novo.
Future<void> recomecarCadastro(BuildContext context, WidgetRef ref) async {
  // Guardados antes do await: o contexto pode deixar de existir durante a espera.
  final mensageiro = ScaffoldMessenger.of(context);
  final rotas = GoRouter.of(context);
  await ref.read(sessaoProvider.notifier).sair();
  rotas.go('/consentimento');
  avisar(mensageiro, ErroCadastroAusente().mensagem);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/mensagens.dart';
import '../state/provedores.dart';

Future<bool> _confirmar(BuildContext context, String titulo, String texto, String acao) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(acao)),
        ],
      ),
    ) ??
    false;

/// Pede confirmação e desliga a conta deste aparelho. O histórico continua guardado na conta.
Future<void> sairDaConta(BuildContext context, WidgetRef ref) async {
  final confirmou = await _confirmar(
    context,
    'Sair da conta?',
    'Seu histórico continua guardado na conta. Neste aparelho, você volta a usar o app '
        'sem login e precisará aceitar o termo de novo.',
    'Sair',
  );
  if (!confirmou || !context.mounted) return;
  await ref.read(sessaoProvider.notifier).sair();
  if (context.mounted) context.go('/consentimento');
}

/// Pede confirmação e apaga tudo do servidor (direito de exclusão, LGPD).
Future<void> _apagarDados(BuildContext context, WidgetRef ref) async {
  final confirmou = await _confirmar(
    context,
    'Apagar meus dados?',
    'Todas as suas avaliações (e a sua conta, se tiver) serão apagadas do servidor. '
        'Isso não pode ser desfeito.',
    'Apagar',
  );
  if (!confirmou || !context.mounted) return;

  try {
    await ref.read(apiProvider).apagarDados(ref.read(armazenamentoProvider).usuarioId);
    await ref.read(sessaoProvider.notifier).sair();
    if (context.mounted) context.go('/consentimento');
  } catch (e) {
    if (context.mounted) avisar(ScaffoldMessenger.of(context), mensagemDeErro(e));
  }
}

/// Menu da barra superior: sair da conta (quando há sessão) e apagar os dados.
class MenuConta extends ConsumerWidget {
  const MenuConta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logado = ref.watch(sessaoProvider) != null;
    return PopupMenuButton<String>(
      onSelected: (opcao) {
        if (opcao == 'sair') sairDaConta(context, ref);
        if (opcao == 'apagar') _apagarDados(context, ref);
      },
      itemBuilder: (_) => [
        if (logado) const PopupMenuItem(value: 'sair', child: Text('Sair da conta')),
        const PopupMenuItem(value: 'apagar', child: Text('Apagar meus dados')),
      ],
    );
  }
}

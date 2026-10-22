import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config.dart';
import '../data/models/sessao.dart';
import '../state/provedores.dart';

class InicioTela extends ConsumerWidget {
  const InicioTela({super.key});

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _sair(BuildContext context, WidgetRef ref) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estilo = Theme.of(context).textTheme;
    final sessao = ref.watch(sessaoProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equilibra'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (op) {
              if (op == 'sair') _sair(context, ref);
              if (op == 'apagar') _apagarDados(context, ref);
            },
            itemBuilder: (_) => [
              if (sessao != null) const PopupMenuItem(value: 'sair', child: Text('Sair da conta')),
              const PopupMenuItem(value: 'apagar', child: Text('Apagar meus dados')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (Config.modoDemo)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              margin: const EdgeInsets.only(bottom: 24),
              child: const ListTile(
                leading: Icon(Icons.science_outlined),
                title: Text('Modo demonstração'),
                subtitle: Text('Sem conexão com a API: o resultado é uma estimativa simulada, '
                    'não o modelo de ML.'),
              ),
            ),
          Text('Como você está?', style: estilo.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Responda 12 perguntas rápidas sobre seus estudos e o uso de IA '
            'e descubra seu nível de risco de burnout.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/questionario'),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Fazer autoavaliação'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/historico'),
            icon: const Icon(Icons.show_chart),
            label: const Text('Meu histórico'),
          ),
          const SizedBox(height: 24),
          CartaoConta(
            sessao: sessao,
            emailDaConta: ref.read(armazenamentoProvider).emailDaConta,
            aoContinuarSemConta: () => _sair(context, ref),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Lembrete: esta é uma ferramenta educativa e não substitui '
                'a avaliação de um profissional de saúde.',
                style: estilo.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Situação da conta: conectado, sessão expirada ou convite para criar uma conta.
class CartaoConta extends StatelessWidget {
  const CartaoConta({
    super.key,
    required this.sessao,
    required this.emailDaConta,
    required this.aoContinuarSemConta,
  });

  final Sessao? sessao;

  /// E-mail da conta ligada ao aparelho, mesmo sem sessão válida (sessão expirada).
  final String? emailDaConta;

  /// Sessão expirada: desliga a conta deste aparelho para seguir sem login
  /// (a autoavaliação nunca pode depender de conta).
  final VoidCallback aoContinuarSemConta;

  @override
  Widget build(BuildContext context) {
    final sessaoAtual = sessao;
    if (sessaoAtual != null) {
      return _Cartao(
        icone: Icons.verified_user_outlined,
        titulo: 'Conectado como ${sessaoAtual.email}',
        texto: 'Seu histórico fica guardado na sua conta.',
      );
    }
    final expirou = emailDaConta != null;
    return _Cartao(
      icone: expirou ? Icons.lock_clock_outlined : Icons.person_add_alt_1_outlined,
      titulo: expirou ? 'Sua sessão expirou' : 'Acompanhe sua evolução',
      texto: expirou
          ? 'Entre de novo como $emailDaConta para ver seu histórico.'
          : 'Crie uma conta gratuita para guardar seu histórico.',
      acao: OverflowBar(
        alignment: MainAxisAlignment.end,
        children: [
          if (expirou)
            TextButton(onPressed: aoContinuarSemConta, child: const Text('Continuar sem conta')),
          TextButton(
            onPressed: () => context.push(expirou ? '/entrar?modo=entrar' : '/entrar'),
            child: Text(expirou ? 'Entrar' : 'Criar conta'),
          ),
        ],
      ),
    );
  }
}

/// Cartão com ícone, título e texto em largura total; a ação (opcional) fica embaixo, à direita.
class _Cartao extends StatelessWidget {
  const _Cartao({required this.icone, required this.titulo, required this.texto, this.acao});

  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, acao == null ? 16 : 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone),
                const SizedBox(width: 12),
                Expanded(child: Text(titulo, style: estilo.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(texto, style: estilo.bodyMedium),
            if (acao != null) Align(alignment: Alignment.centerRight, child: acao),
          ],
        ),
      ),
    );
  }
}

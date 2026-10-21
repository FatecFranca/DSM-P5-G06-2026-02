import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config.dart';
import '../state/provedores.dart';

class InicioTela extends ConsumerWidget {
  const InicioTela({super.key});

  Future<void> _apagarDados(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar meus dados?'),
        content: const Text(
          'Todas as suas avaliações serão apagadas do servidor. Isso não pode ser desfeito.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    final armazenamento = ref.read(armazenamentoProvider);
    try {
      await ref.read(apiProvider).apagarDados(armazenamento.usuarioId);
      await armazenamento.limpar();
      if (context.mounted) context.go('/consentimento');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estilo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equilibra'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (op) {
              if (op == 'apagar') _apagarDados(context, ref);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'apagar', child: Text('Apagar meus dados')),
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
          const SizedBox(height: 32),
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

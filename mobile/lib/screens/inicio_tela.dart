import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/provedores.dart';
import '../widgets/aviso_modo_demo.dart';
import '../widgets/menu_conta.dart';

/// Tela inicial de quem não entrou numa conta (quem entrou vai para a Home, com o painel).
class InicioTela extends ConsumerWidget {
  const InicioTela({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estilo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equilibra'),
        actions: const [MenuConta()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const AvisoModoDemo(),
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
            emailDaConta: ref.read(armazenamentoProvider).emailDaConta,
            aoContinuarSemConta: () => sairDaConta(context, ref),
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

/// Convite para criar uma conta ou, se a conta deste aparelho perdeu a sessão, aviso de sessão expirada.
class CartaoConta extends StatelessWidget {
  const CartaoConta({super.key, required this.emailDaConta, required this.aoContinuarSemConta});

  /// E-mail da conta ligada ao aparelho, mesmo sem sessão válida (sessão expirada).
  final String? emailDaConta;

  /// Sessão expirada: desliga a conta deste aparelho para seguir sem login
  /// (a autoavaliação nunca pode depender de conta).
  final VoidCallback aoContinuarSemConta;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    final expirou = emailDaConta != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(expirou ? Icons.lock_clock_outlined : Icons.person_add_alt_1_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    expirou ? 'Sua sessão expirou' : 'Acompanhe sua evolução',
                    style: estilo.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              expirou
                  ? 'Entre de novo como $emailDaConta para ver seu painel e seu histórico.'
                  : 'Crie uma conta gratuita para ter um painel com a média das suas respostas e dicas do que melhorar.',
              style: estilo.bodyMedium,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OverflowBar(
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
            ),
          ],
        ),
      ),
    );
  }
}

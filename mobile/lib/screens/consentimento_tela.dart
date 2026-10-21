import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/provedores.dart';

/// Primeira tela: termo de uso e privacidade (LGPD). Sem aceite, o app não segue.
class ConsentimentoTela extends ConsumerStatefulWidget {
  const ConsentimentoTela({super.key});

  @override
  ConsumerState<ConsentimentoTela> createState() => _ConsentimentoTelaState();
}

class _ConsentimentoTelaState extends ConsumerState<ConsentimentoTela> {
  bool _aceito = false;
  bool _enviando = false;

  Future<void> _continuar() async {
    setState(() => _enviando = true);
    final armazenamento = ref.read(armazenamentoProvider);
    try {
      await ref.read(apiProvider).registrarUsuario(armazenamento.usuarioId);
      await armazenamento.registrarConsentimento();
      if (mounted) context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.spa_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Bem-vindo ao Equilibra', style: estilo.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Uma autoavaliação rápida do seu risco de burnout a partir dos seus '
              'hábitos de estudo e de uso de inteligência artificial.',
            ),
            const SizedBox(height: 24),
            Text('Antes de começar', style: estilo.titleMedium),
            const SizedBox(height: 8),
            const _Item('Isto não é um diagnóstico. O resultado é uma estimativa educativa.'),
            const _Item('Não pedimos nome, e-mail nem telefone. Você é identificado por um código anônimo.'),
            const _Item('Suas respostas ficam guardadas para mostrar seu histórico.'),
            const _Item('Você pode apagar todos os seus dados a qualquer momento.'),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _aceito,
              onChanged: (v) => setState(() => _aceito = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Li e aceito o termo de uso e privacidade'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _aceito && !_enviando ? _continuar : null,
              child: _enviando
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Aceitar e continuar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(texto)),
          ],
        ),
      );
}

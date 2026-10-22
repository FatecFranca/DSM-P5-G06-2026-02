import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/tema.dart';
import '../data/models/resultado.dart';

class ResultadoTela extends StatelessWidget {
  const ResultadoTela({super.key, required this.resultado, this.convidarParaConta = false});

  final Resultado resultado;

  /// Mostra o convite para criar conta (usuário sem login). Nunca esconde o resultado.
  final bool convidarParaConta;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    final cor = Tema.corDoRisco(resultado.nivelRisco);
    final p = resultado.probabilidades;

    return Scaffold(
      appBar: AppBar(title: const Text('Seu resultado')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            // Cor opaca: com transparência, a sombra do cartão aparece pelo fundo e o "suja".
            color: Color.alphaBlend(cor.withValues(alpha: 0.12), Theme.of(context).colorScheme.surface),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: cor, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(Tema.rotuloDoRisco(resultado.nivelRisco),
                      style: estilo.headlineMedium?.copyWith(color: cor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _BarraProbabilidade('Baixo', p.baixo, Tema.corDoRisco('baixo')),
                  _BarraProbabilidade('Médio', p.medio, Tema.corDoRisco('medio')),
                  _BarraProbabilidade('Alto', p.alto, Tema.corDoRisco('alto')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('O que você pode fazer', style: estilo.titleMedium),
          const SizedBox(height: 8),
          for (final dica in resultado.orientacoes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(dica),
            ),
          if (resultado.apoio != null) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Precisa conversar?'),
                subtitle: Text(resultado.apoio!),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(resultado.aviso, style: estilo.bodySmall),
          if (convidarParaConta) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Quer acompanhar sua evolução?'),
                subtitle: const Text('Crie uma conta gratuita para guardar seu histórico.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/entrar'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: () => context.go('/'), child: const Text('Voltar ao início')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.pushReplacement('/historico'),
            child: const Text('Ver meu histórico'),
          ),
        ],
      ),
    );
  }
}

class _BarraProbabilidade extends StatelessWidget {
  const _BarraProbabilidade(this.rotulo, this.valor, this.cor);

  final String rotulo;
  final double valor;
  final Color cor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 56, child: Text(rotulo)),
            Expanded(
              child: LinearProgressIndicator(
                value: valor,
                color: cor,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text('${(valor * 100).round()}%', textAlign: TextAlign.end),
            ),
          ],
        ),
      );
}

import 'package:flutter/material.dart';

import '../core/config.dart';

/// Faixa que deixa claro quando o app roda sem a API. Fora do modo demo, não mostra nada.
class AvisoModoDemo extends StatelessWidget {
  const AvisoModoDemo({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Config.modoDemo) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      margin: const EdgeInsets.only(bottom: 24),
      child: const ListTile(
        leading: Icon(Icons.science_outlined),
        title: Text('Modo demonstração'),
        subtitle: Text('Sem conexão com a API: o resultado é uma estimativa simulada, não o modelo de ML.'),
      ),
    );
  }
}

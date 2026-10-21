import 'package:flutter/material.dart';

/// Lista suspensa a partir de um mapa {valor: rótulo}.
class CampoEscolha extends StatelessWidget {
  const CampoEscolha({
    super.key,
    required this.rotulo,
    required this.opcoes,
    required this.valor,
    required this.aoMudar,
  });

  final String rotulo;
  final Map<String, String> opcoes;
  final String valor;
  final ValueChanged<String> aoMudar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: valor,
        decoration: InputDecoration(labelText: rotulo),
        items: [
          for (final e in opcoes.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) {
          if (v != null) aoMudar(v);
        },
      ),
    );
  }
}

/// Controle deslizante com o valor atual mostrado ao lado do rótulo.
class CampoDeslizante extends StatelessWidget {
  const CampoDeslizante({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.min,
    required this.max,
    required this.divisoes,
    required this.aoMudar,
    this.formatar,
    this.ajuda,
  });

  final String rotulo;
  final double valor;
  final double min;
  final double max;
  final int divisoes;
  final ValueChanged<double> aoMudar;
  final String Function(double)? formatar;
  final String? ajuda;

  @override
  Widget build(BuildContext context) {
    final texto = formatar?.call(valor) ?? valor.toStringAsFixed(0);
    final estilo = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(rotulo, style: estilo.titleSmall)),
              Text(texto, style: estilo.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          if (ajuda != null) Text(ajuda!, style: estilo.bodySmall),
          Slider(
            value: valor,
            min: min,
            max: max,
            divisions: divisoes,
            label: texto,
            onChanged: aoMudar,
          ),
        ],
      ),
    );
  }
}

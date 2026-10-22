import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/tema.dart';
import '../data/api_cliente.dart';
import '../data/models/resultado.dart';
import '../state/provedores.dart';

class HistoricoTela extends ConsumerWidget {
  const HistoricoTela({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historico = ref.watch(historicoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meu histórico')),
      body: historico.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                if (e is ErroSessao)
                  FilledButton(
                    onPressed: () => context.push('/entrar?modo=entrar'),
                    child: const Text('Entrar'),
                  )
                else
                  OutlinedButton(
                    onPressed: () => ref.invalidate(historicoProvider),
                    child: const Text('Tentar de novo'),
                  ),
              ],
            ),
          ),
        ),
        data: (itens) => itens.isEmpty
            ? const Center(child: Text('Você ainda não fez nenhuma avaliação.'))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(historicoProvider.future),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (itens.length >= 2) _GraficoRiscoAlto(itens),
                    for (final a in itens) _ItemHistorico(a),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Evolução da probabilidade de risco alto, da avaliação mais antiga à mais recente.
class _GraficoRiscoAlto extends StatelessWidget {
  const _GraficoRiscoAlto(this.itens);
  final List<AvaliacaoResumo> itens;

  @override
  Widget build(BuildContext context) {
    final cronologico = itens.reversed.toList();
    final cor = Tema.corDoRisco('alto');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text('Chance de risco alto ao longo do tempo',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 1,
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 0.5,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text('${(v * 100).round()}%'),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < cronologico.length; i++)
                          FlSpot(i.toDouble(), cronologico[i].probabilidades.alto),
                      ],
                      color: cor,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemHistorico extends StatelessWidget {
  const _ItemHistorico(this.a);
  final AvaliacaoResumo a;

  @override
  Widget build(BuildContext context) {
    final cor = Tema.corDoRisco(a.nivelRisco);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.15),
          child: Icon(Icons.circle, color: cor, size: 16),
        ),
        title: Text(Tema.rotuloDoRisco(a.nivelRisco)),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy HH:mm').format(a.criadoEm)} · '
          '${a.horasIaSemana.toStringAsFixed(0)} h de IA/semana',
        ),
        trailing: Text('${(a.probabilidades.alto * 100).round()}% alto'),
      ),
    );
  }
}

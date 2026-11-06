import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/mensagens.dart';
import '../core/recomecar.dart';
import '../core/tema.dart';
import '../data/api_cliente.dart';
import '../data/models/painel.dart';
import '../data/opcoes.dart';
import '../state/provedores.dart';
import '../widgets/aviso_modo_demo.dart';
import '../widgets/menu_conta.dart';

/// Tela principal de quem entrou numa conta: dashboard com a média de todas as respostas e dicas.
class HomeTela extends ConsumerWidget {
  const HomeTela({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estilo = Theme.of(context).textTheme;
    final sessao = ref.watch(sessaoProvider);
    final painel = ref.watch(painelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Equilibra'), actions: const [MenuConta()]),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(painelProvider);
          try {
            await ref.read(painelProvider.future);
          } catch (_) {
            // O erro já aparece na tela, no painel.when abaixo.
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const AvisoModoDemo(),
            Text('Olá!', style: estilo.headlineSmall),
            if (sessao != null) Text('Conectado como ${sessao.email}', style: estilo.bodyMedium),
            const SizedBox(height: 20),
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
            // Sem sessão, a conta acabou de sair e esta tela já está indo embora.
            if (sessao != null)
              painel.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (erro, _) => _ErroDoPainel(erro),
                data: (dados) => dados.vazio ? const _PainelVazio() : _Dashboard(dados),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErroDoPainel extends ConsumerWidget {
  const _ErroDoPainel(this.erro);
  final Object erro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget acao;
    if (erro is ErroSessao) {
      acao = FilledButton(onPressed: () => context.push('/entrar?modo=entrar'), child: const Text('Entrar'));
    } else if (erro is ErroCadastroAusente) {
      acao = FilledButton(
        onPressed: () => recomecarCadastro(context, ref),
        child: const Text('Aceitar o termo de novo'),
      );
    } else {
      acao = OutlinedButton(onPressed: () => ref.invalidate(painelProvider), child: const Text('Tentar de novo'));
    }
    return Column(
      children: [
        Text(mensagemDeErro(erro), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        acao,
      ],
    );
  }
}

class _PainelVazio extends StatelessWidget {
  const _PainelVazio();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.insights_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text('Seu painel aparece aqui', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Faça sua primeira autoavaliação para ver a média das suas respostas '
            'e dicas do que você pode melhorar.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard(this.painel);
  final Painel painel;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    final apoio = painel.apoio;
    final probabilidades = painel.probabilidadesMedias;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CartaoRisco(painel),
        if (apoio != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Precisa conversar?'),
              subtitle: Text(apoio),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Dicas para você', style: estilo.titleMedium),
        const SizedBox(height: 4),
        for (final dica in painel.dicas) _CartaoDica(dica),
        const SizedBox(height: 24),
        Text('Suas médias', style: estilo.titleMedium),
        const SizedBox(height: 4),
        Text('A marca em cada barra é a média dos estudantes com risco baixo.', style: estilo.bodySmall),
        const SizedBox(height: 12),
        for (final medida in _medidas)
          if (painel.medias[medida.chave] case final media?)
            _BarraDeMedia(medida: medida, media: media, referencia: painel.referencias[medida.chave]),
        if (painel.medias['assinatura_paga'] case final fracao?)
          _LinhaResposta('Paga assinatura de IA', '${(fracao * 100).round()}% das vezes'),
        const SizedBox(height: 16),
        if (probabilidades != null) ...[
          Text('Chance média de cada nível', style: estilo.titleMedium),
          const SizedBox(height: 8),
          _BarraDeChance('Baixo', probabilidades.baixo, Tema.corDoRisco('baixo')),
          _BarraDeChance('Médio', probabilidades.medio, Tema.corDoRisco('medio')),
          _BarraDeChance('Alto', probabilidades.alto, Tema.corDoRisco('alto')),
          const SizedBox(height: 24),
        ],
        Text('Suas respostas mais comuns', style: estilo.titleMedium),
        const SizedBox(height: 8),
        for (final pergunta in _perguntas)
          if (painel.maisComuns[pergunta.chave] case final valor?)
            _LinhaResposta(pergunta.rotulo, pergunta.opcoes[valor] ?? valor),
        const SizedBox(height: 24),
        Text(painel.notaReferencias, style: estilo.bodySmall),
        const SizedBox(height: 8),
        Text(painel.aviso, style: estilo.bodySmall),
      ],
    );
  }
}

/// Resumo: nível da avaliação mais recente, quantas avaliações e a tendência.
class _CartaoRisco extends StatelessWidget {
  const _CartaoRisco(this.painel);
  final Painel painel;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    final risco = painel.riscoAtual ?? 'baixo';
    final cor = Tema.corDoRisco(risco);
    final total = painel.totalAvaliacoes;
    final ultima = painel.ultimaEm;
    return Card(
      // Cor opaca: com transparência, a sombra do cartão aparece pelo fundo e o "suja".
      color: Color.alphaBlend(cor.withValues(alpha: 0.12), Theme.of(context).colorScheme.surface),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cor, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seu risco atual', style: estilo.bodyMedium),
            Text(
              Tema.rotuloDoRisco(risco),
              style: estilo.headlineMedium?.copyWith(color: cor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(total == 1 ? '1 avaliação' : '$total avaliações'),
            if (ultima != null) Text('Última em ${DateFormat('dd/MM/yyyy').format(ultima)}'),
            if (painel.tendencia case final tendencia?) ...[const SizedBox(height: 8), _Tendencia(tendencia)],
          ],
        ),
      ),
    );
  }
}

class _Tendencia extends StatelessWidget {
  const _Tendencia(this.tendencia);
  final String tendencia;

  @override
  Widget build(BuildContext context) {
    final (icone, texto, cor) = switch (tendencia) {
      'melhorando' => (Icons.trending_down, 'Melhorando desde a avaliação anterior', Tema.corDoRisco('baixo')),
      'piorando' => (Icons.trending_up, 'Piorou desde a avaliação anterior', Tema.corDoRisco('alto')),
      _ => (Icons.trending_flat, 'Estável desde a avaliação anterior', Theme.of(context).colorScheme.onSurface),
    };
    return Row(
      children: [
        Icon(icone, color: cor),
        const SizedBox(width: 8),
        Expanded(child: Text(texto)),
      ],
    );
  }
}

class _CartaoDica extends StatelessWidget {
  const _CartaoDica(this.dica);
  final DicaPainel dica;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(dica.ehParaManter ? Icons.check_circle_outline : Icons.lightbulb_outline),
      title: Text(dica.titulo),
      subtitle: Text(dica.texto),
    ),
  );
}

/// Como mostrar a média de uma resposta numérica.
class _Medida {
  const _Medida(this.chave, this.rotulo, this.maximo, this.unidade);
  final String chave;
  final String rotulo;
  final double maximo;
  final String unidade;
}

const _medidas = [
  _Medida('horas_ia_semana', 'Horas por semana usando IA', 60, ' h'),
  _Medida('horas_estudo_semana', 'Horas por semana estudando sem IA', 60, ' h'),
  _Medida('dependencia_ia', 'Dependência da IA', 10, ' de 10'),
  _Medida('ansiedade_provas', 'Ansiedade em época de provas', 10, ' de 10'),
  _Medida('nota_semestre_anterior', 'Média do semestre anterior', 10, ''),
  _Medida('qtd_ferramentas_ia', 'Ferramentas de IA que você usa', 10, ''),
];

/// Como mostrar a resposta mais comum de uma pergunta de escolha.
class _Pergunta {
  const _Pergunta(this.chave, this.rotulo, this.opcoes);
  final String chave;
  final String rotulo;
  final Map<String, String> opcoes;
}

const _perguntas = [
  _Pergunta('uso_principal_ia', 'Uso principal da IA', Opcoes.usoPrincipalIa),
  _Pergunta('nivel_prompt', 'Habilidade em escrever prompts', Opcoes.nivelPrompt),
  _Pergunta('area_curso', 'Área do curso', Opcoes.areaCurso),
  _Pergunta('ano_curso', 'Ano do curso', Opcoes.anoCurso),
  _Pergunta('politica_instituicao', 'Regra da instituição sobre IA', Opcoes.politicaInstituicao),
];

/// Número com uma casa decimal e vírgula, como se lê em português.
String _numero(double valor) => valor.toStringAsFixed(1).replaceAll('.', ',');

/// Média do estudante em barra, com uma marca na posição da referência.
class _BarraDeMedia extends StatelessWidget {
  const _BarraDeMedia({required this.medida, required this.media, required this.referencia});

  final _Medida medida;
  final double media;
  final double? referencia;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    final ref = referencia;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(medida.rotulo, style: estilo.bodyMedium)),
              Text(
                '${_numero(media)}${medida.unidade}',
                style: estilo.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, limites) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                LinearProgressIndicator(
                  value: (media / medida.maximo).clamp(0, 1),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                if (ref != null)
                  Positioned(
                    left: limites.maxWidth * (ref / medida.maximo).clamp(0, 1) - 1,
                    child: Container(width: 3, height: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
              ],
            ),
          ),
          if (ref != null) ...[
            const SizedBox(height: 4),
            Text('Referência: ${_numero(ref)}${medida.unidade}', style: estilo.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _BarraDeChance extends StatelessWidget {
  const _BarraDeChance(this.rotulo, this.valor, this.cor);

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
        SizedBox(width: 48, child: Text('${(valor * 100).round()}%', textAlign: TextAlign.end)),
      ],
    ),
  );
}

class _LinhaResposta extends StatelessWidget {
  const _LinhaResposta(this.rotulo, this.valor);

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(rotulo)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

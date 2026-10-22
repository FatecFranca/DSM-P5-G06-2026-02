import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/api_cliente.dart';
import '../data/models/questionario.dart';
import '../data/opcoes.dart';
import '../state/provedores.dart';
import '../widgets/campos.dart';

class QuestionarioTela extends ConsumerStatefulWidget {
  const QuestionarioTela({super.key});

  @override
  ConsumerState<QuestionarioTela> createState() => _QuestionarioTelaState();
}

class _QuestionarioTelaState extends ConsumerState<QuestionarioTela> {
  final _q = Questionario();
  bool _enviando = false;

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      final id = ref.read(armazenamentoProvider).usuarioId;
      final resultado = await ref.read(apiProvider).prever(id, _q);
      ref.invalidate(historicoProvider);
      if (mounted) context.pushReplacement('/resultado', extra: resultado);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'),
        action: e is ErroSessao
            ? SnackBarAction(label: 'Entrar', onPressed: () => context.push('/entrar?modo=entrar'))
            : null,
      ));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('Autoavaliação')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text('Sobre o seu curso', style: titulo),
          const SizedBox(height: 12),
          CampoEscolha(
            rotulo: 'Área do curso',
            opcoes: Opcoes.areaCurso,
            valor: _q.areaCurso,
            aoMudar: (v) => setState(() => _q.areaCurso = v),
          ),
          CampoEscolha(
            rotulo: 'Em que ano você está',
            opcoes: Opcoes.anoCurso,
            valor: _q.anoCurso,
            aoMudar: (v) => setState(() => _q.anoCurso = v),
          ),
          CampoEscolha(
            rotulo: 'Regra da sua instituição sobre IA',
            opcoes: Opcoes.politicaInstituicao,
            valor: _q.politicaInstituicao,
            aoMudar: (v) => setState(() => _q.politicaInstituicao = v),
          ),
          CampoDeslizante(
            rotulo: 'Média do semestre anterior',
            valor: _q.notaSemestreAnterior,
            min: 0,
            max: 10,
            divisoes: 20,
            formatar: (v) => v.toStringAsFixed(1),
            aoMudar: (v) => setState(() => _q.notaSemestreAnterior = v),
          ),
          const Divider(height: 32),
          Text('Sua rotina de estudos', style: titulo),
          const SizedBox(height: 12),
          CampoDeslizante(
            rotulo: 'Horas por semana usando IA',
            valor: _q.horasIaSemana,
            min: 0,
            max: 60,
            divisoes: 60,
            formatar: (v) => '${v.toStringAsFixed(0)} h',
            aoMudar: (v) => setState(() => _q.horasIaSemana = v),
          ),
          CampoDeslizante(
            rotulo: 'Horas por semana estudando sem IA',
            valor: _q.horasEstudoSemana,
            min: 0,
            max: 60,
            divisoes: 60,
            formatar: (v) => '${v.toStringAsFixed(0)} h',
            aoMudar: (v) => setState(() => _q.horasEstudoSemana = v),
          ),
          const Divider(height: 32),
          Text('Como você usa a IA', style: titulo),
          const SizedBox(height: 12),
          CampoEscolha(
            rotulo: 'Uso principal',
            opcoes: Opcoes.usoPrincipalIa,
            valor: _q.usoPrincipalIa,
            aoMudar: (v) => setState(() => _q.usoPrincipalIa = v),
          ),
          CampoEscolha(
            rotulo: 'Sua habilidade em escrever prompts',
            opcoes: Opcoes.nivelPrompt,
            valor: _q.nivelPrompt,
            aoMudar: (v) => setState(() => _q.nivelPrompt = v),
          ),
          CampoDeslizante(
            rotulo: 'Quantas ferramentas de IA você usa',
            valor: _q.qtdFerramentasIa.toDouble(),
            min: 0,
            max: 10,
            divisoes: 10,
            aoMudar: (v) => setState(() => _q.qtdFerramentasIa = v.round()),
          ),
          SwitchListTile(
            value: _q.assinaturaPaga,
            onChanged: (v) => setState(() => _q.assinaturaPaga = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Paga alguma assinatura de IA'),
          ),
          const Divider(height: 32),
          Text('Como você se sente', style: titulo),
          const SizedBox(height: 12),
          CampoDeslizante(
            rotulo: 'Quanto você depende da IA',
            ajuda: '1 = nada, 10 = não consigo estudar sem',
            valor: _q.dependenciaIa.toDouble(),
            min: 1,
            max: 10,
            divisoes: 9,
            aoMudar: (v) => setState(() => _q.dependenciaIa = v.round()),
          ),
          CampoDeslizante(
            rotulo: 'Ansiedade em época de provas',
            ajuda: '1 = tranquilo, 10 = muito ansioso',
            valor: _q.ansiedadeProvas.toDouble(),
            min: 1,
            max: 10,
            divisoes: 9,
            aoMudar: (v) => setState(() => _q.ansiedadeProvas = v.round()),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _enviando ? null : _enviar,
            child: _enviando
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Ver meu resultado'),
          ),
        ],
      ),
    );
  }
}

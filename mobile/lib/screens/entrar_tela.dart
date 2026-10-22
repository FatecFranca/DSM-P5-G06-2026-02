import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config.dart';
import '../core/validacoes.dart';
import '../state/provedores.dart';

enum ModoConta { criar, entrar }

/// Criar conta ou entrar. A conta é opcional: serve para guardar o histórico
/// e usá-lo em outro aparelho; o resultado da autoavaliação nunca depende dela.
class EntrarTela extends ConsumerStatefulWidget {
  const EntrarTela({super.key, this.modoInicial = ModoConta.criar});

  final ModoConta modoInicial;

  @override
  ConsumerState<EntrarTela> createState() => _EntrarTelaState();
}

class _EntrarTelaState extends ConsumerState<EntrarTela> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  late ModoConta _modo = widget.modoInicial;
  bool _aceitouTermo = false;
  bool _senhaVisivel = false;
  bool _enviando = false;

  bool get _criando => _modo == ModoConta.criar;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  void _avisar(String mensagem) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    if (_criando && !_aceitouTermo) {
      _avisar('Aceite o termo para criar a conta.');
      return;
    }

    setState(() => _enviando = true);
    final controle = ref.read(sessaoProvider.notifier);
    final email = _email.text.trim().toLowerCase();
    try {
      if (_criando) {
        await controle.cadastrar(email: email, senha: _senha.text);
      } else {
        await controle.entrar(email: email, senha: _senha.text);
      }
      ref.invalidate(historicoProvider);
      if (!mounted) return;
      _avisar(_criando ? 'Conta criada! Seu histórico agora fica guardado.' : 'Bem-vindo de volta!');
      context.go('/');
    } catch (e) {
      if (mounted) _avisar('$e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sua conta')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Acompanhe sua evolução', style: estilo.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Com uma conta, seu histórico fica guardado e você pode vê-lo em outro celular. '
            'A autoavaliação continua livre, com ou sem conta.',
          ),
          const SizedBox(height: 24),
          SegmentedButton<ModoConta>(
            segments: const [
              ButtonSegment(value: ModoConta.criar, label: Text('Criar conta')),
              ButtonSegment(value: ModoConta.entrar, label: Text('Entrar')),
            ],
            selected: {_modo},
            onSelectionChanged: (s) => setState(() => _modo = s.first),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formulario,
            child: AutofillGroup(
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: Validacoes.email,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _senha,
                    obscureText: !_senhaVisivel,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      helperText: _criando ? 'Pelo menos ${Validacoes.tamanhoMinimoSenha} caracteres' : null,
                      suffixIcon: IconButton(
                        tooltip: _senhaVisivel ? 'Esconder senha' : 'Mostrar senha',
                        icon: Icon(_senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                      ),
                    ),
                    autofillHints: [_criando ? AutofillHints.newPassword : AutofillHints.password],
                    textInputAction: _criando ? TextInputAction.next : TextInputAction.done,
                    validator: _criando ? Validacoes.senhaNova : Validacoes.senhaLogin,
                    onFieldSubmitted: _criando ? null : (_) => _enviar(),
                  ),
                  if (_criando) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmacao,
                      obscureText: !_senhaVisivel,
                      decoration: const InputDecoration(labelText: 'Confirme a senha'),
                      validator: (v) => Validacoes.confirmacao(v, _senha.text),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _aceitouTermo,
                      onChanged: (v) => setState(() => _aceitouTermo = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Aceito o termo de uso e privacidade (versão ${Config.versaoTermoConta})'),
                      subtitle: const Text(
                        'Seu e-mail fica guardado só para identificar sua conta. A senha nunca é guardada '
                        'em texto, e você pode apagar tudo quando quiser.',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _enviando ? null : _enviar,
            child: _enviando
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_criando ? 'Criar conta' : 'Entrar'),
          ),
          if (Config.modoDemo) ...[
            const SizedBox(height: 16),
            Text('Modo demonstração: a conta é simulada no aparelho.', style: estilo.bodySmall),
          ],
        ],
      ),
    );
  }
}

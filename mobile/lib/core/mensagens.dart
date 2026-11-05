import 'package:flutter/material.dart';

import '../data/api_cliente.dart';

/// Texto de um erro para mostrar ao usuário.
/// Erros da API já trazem mensagem pronta; qualquer outro é uma falha interna do app:
/// o usuário vê uma mensagem genérica e o detalhe vai para o log (nunca "Instance of ...").
String mensagemDeErro(Object erro) {
  if (erro is ErroApi) return erro.mensagem;
  debugPrint('Erro inesperado no app: $erro');
  return 'Algo deu errado. Tente de novo.';
}

/// Mostra um aviso na parte de baixo da tela. O aviso novo substitui o anterior: sem isso eles
/// entram em fila e o usuário lê mensagens atrasadas (ex.: "senha incorreta" depois do bloqueio).
void avisar(ScaffoldMessengerState mensageiro, String mensagem, {SnackBarAction? acao}) {
  mensageiro
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(mensagem), action: acao));
}

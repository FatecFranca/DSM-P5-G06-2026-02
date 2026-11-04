import 'package:flutter/foundation.dart';

import '../data/api_cliente.dart';

/// Texto de um erro para mostrar ao usuário.
/// Erros da API já trazem mensagem pronta; qualquer outro é uma falha interna do app:
/// o usuário vê uma mensagem genérica e o detalhe vai para o log (nunca "Instance of ...").
String mensagemDeErro(Object erro) {
  if (erro is ErroApi) return erro.mensagem;
  debugPrint('Erro inesperado no app: $erro');
  return 'Algo deu errado. Tente de novo.';
}

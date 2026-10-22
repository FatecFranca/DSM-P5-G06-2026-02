# App Equilibra (Flutter)

## Telas

| Rota | Tela | O que faz |
| --- | --- | --- |
| `/consentimento` | Consentimento | Termo de uso e privacidade (LGPD). Registra o id anônimo na API |
| `/` | Início | Acesso à autoavaliação e ao histórico; situação da conta; menu para sair e apagar os dados |
| `/questionario` | Questionário | 12 perguntas com listas, controles deslizantes e chave liga/desliga |
| `/resultado` | Resultado | Nível de risco, probabilidades, orientações e apoio (CVV) no risco alto; convite para criar conta |
| `/historico` | Histórico | Gráfico da chance de risco alto e lista das avaliações |
| `/entrar` | Sua conta | Criar conta ou entrar (e-mail e senha). `/entrar?modo=entrar` abre direto no login |

## Conta (opcional)

- O app funciona sem conta; o **resultado nunca depende de login**.
- Criar conta transforma o usuário anônimo do aparelho em conta: o histórico continua o mesmo.
  O cadastro exige o aceite do termo **2.0** (que inclui a guarda do e-mail).
- Entrar numa conta une a ela as avaliações anônimas do aparelho.
- O token de login fica no **armazenamento seguro** do sistema (`flutter_secure_storage`: Keystore no Android),
  nunca nas preferências comuns. Ele vale 7 dias.
- Sessão expirada: o início avisa e oferece **Entrar** ou **Continuar sem conta**.
- Sair da conta (ou apagar os dados) volta o aparelho a anônimo, com um novo id e o termo pedido de novo.
- No modo demonstração a conta é simulada: qualquer e-mail e senha válidos entram.

## Organização do código

```
lib/
  main.dart               ponto de entrada (carrega preferências e a sessão salva, inicia o Riverpod)
  core/                   configuração, tema, rotas (go_router) e validações dos formulários
  data/                   cliente da API (dio), modo demo, armazenamentos (local e seguro), modelos e opções
  state/provedores.dart   provedores Riverpod (estado), incluindo o controle da sessão de login
  screens/                uma tela por arquivo
  widgets/                campos reutilizáveis do formulário
test/                     testes de unidade e de widgets (apoio/falsos.dart: API falsa para os testes)
```

## Primeira vez: gerar as pastas Android e iOS

O repositório guarda só o código Dart. Na pasta `mobile/`, rode uma vez:

```bash
flutter create --org br.edu.fatecfranca --project-name equilibra --platforms=android,ios .
flutter pub get
```

O comando cria as pastas `android/` e `ios/` e não sobrescreve os arquivos que já existem em `lib/` e `test/`. Se ele trocar o `lib/main.dart` ou o `test/widget_test.dart` pelo exemplo do contador, desfaça com `git checkout -- lib test`. Requer Flutter 3.35 ou mais novo.

(Já feito em 20/10/2026, com as plataformas android, ios e web. Os passos abaixo também já foram aplicados.)

Depois, em `android/app/src/main/AndroidManifest.xml`:

1. Acima da tag `<application`, adicione a permissão de internet (necessária na versão de release):
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
2. Somente enquanto a API local rodar sem HTTPS, adicione `android:usesCleartextTraffic="true"` dentro da tag `<application ...>`. Remova antes da entrega, porque a API no Azure usa HTTPS.

## Rodar

Com a API rodando no computador (`docker compose up`, na raiz):

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8000 --dart-define=API_KEY=troque-esta-chave
```

- No emulador Android, `10.0.2.2` é o localhost do computador.
- Num celular físico, use o IP do computador na rede, por exemplo `http://192.168.0.10:8000`.
- Com a API no Azure, use `API_URL=https://<seu-app>.azurecontainerapps.io`.

### Modo demonstração (sem a API)

Para apresentar o app sem o servidor no ar:

```bash
flutter run --dart-define=MODO_DEMO=true                      # emulador/celular
flutter run -d chrome --dart-define=MODO_DEMO=true            # navegador
```

A tela inicial mostra o aviso "Modo demonstração". O resultado vem de uma regra simples em
`lib/data/api_demo.dart` (**não** é o modelo de ML) e o histórico fica salvo só no aparelho.
Textos de orientação, aviso e apoio (CVV) são os mesmos da API.

### Problema conhecido: caminho com acento

Com o projeto numa pasta com acento (ex.: `Área de Trabalho`), o `flutter analyze` quebra
(erro `FormatException` no servidor de análise). Use `dart analyze`, que faz a mesma análise,
ou mova o projeto para um caminho sem acento (ex.: `C:\dev\equilibra`).

## Testes

```bash
flutter analyze
flutter test
```

## Próximos passos (Sprint 5)

- Notificação semanal lembrando de refazer a avaliação (`flutter_local_notifications`).
- Áudio curto de pausa guiada (`audioplayers`).

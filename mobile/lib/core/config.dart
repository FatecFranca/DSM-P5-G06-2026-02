/// Configurações passadas na hora de rodar/compilar o app:
///
///   flutter run --dart-define=API_URL=http://10.0.2.2:8000 --dart-define=API_KEY=troque-esta-chave
///
/// 10.0.2.2 é o "localhost" do computador visto de dentro do emulador Android.
/// Em produção, API_URL aponta para o endereço HTTPS do Azure Container Apps.
class Config {
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: 'troque-esta-chave',
  );
  static const versaoTermo = '1.0';
  /// Termo aceito ao criar conta: inclui a guarda do e-mail.
  static const versaoTermoConta = '2.0';

  /// --dart-define=MODO_DEMO=true: roda sem a API (ver data/api_demo.dart).
  static const modoDemo = bool.fromEnvironment('MODO_DEMO');
}

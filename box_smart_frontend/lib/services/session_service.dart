import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  // 💾 Salva a sessão completa com todos os dados do cliente
  static Future<void> salvarSessao({
    required String token,
    required int clienteId,
    required String clienteNome,
    String? email,
    String? telefone,
    String? cpfCliente,
    bool ehMembroClube = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setInt('clienteId', clienteId);
    await prefs.setString('clienteNome', clienteNome);

    if (email != null) await prefs.setString('email', email);
    if (telefone != null) await prefs.setString('telefone', telefone);
    if (cpfCliente != null) await prefs.setString('cpf', cpfCliente);

    await prefs.setBool('ehMembroClube', ehMembroClube);
  }

  // 🌟 MÉTODO COMPATIBILIZADO PARA EVITAR O ERRO EM TELAS ANTIGAS
  static Future<void> salvarClube(String s, {required bool ehMembroClube}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ehMembroClube', ehMembroClube);
  }

  // 📂 Carrega a sessão salva no dispositivo
  static Future<Map<String, dynamic>> carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token': prefs.getString('token') ?? '',
      'clienteId': prefs.getInt('clienteId') ?? 0,
      'clienteNome': prefs.getString('clienteNome') ?? 'Cliente',
      'email': prefs.getString('email') ?? 'Não informado',
      'telefone': prefs.getString('telefone') ?? 'Não informado',
      'cpf': prefs.getString('cpf') ?? '',
      'ehMembroClube': prefs.getBool('ehMembroClube') ?? false,
    };
  }

  // 🚪 Limpa a sessão (Logout)
  static Future<void> limparSessao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
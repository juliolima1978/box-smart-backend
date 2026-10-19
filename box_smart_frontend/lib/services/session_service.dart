import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _keyToken = 'auth_token';
  static const String _keyClienteId = 'cliente_id';
  static const String _keyClienteNome = 'cliente_nome';
  static const String _keyCpfCliente = 'cpf_cliente';
  static const String _keyMembroClube = 'eh_membro_clube';

  // 💾 Salvar dados completos no login
  static Future<void> salvarSessao({
    required String token,
    required int clienteId,
    required String clienteNome,
    String? cpfCliente,
    bool ehMembroClube = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setInt(_keyClienteId, clienteId);
    await prefs.setString(_keyClienteNome, clienteNome);
    if (cpfCliente != null && cpfCliente.isNotEmpty) {
      await prefs.setString(_keyCpfCliente, cpfCliente);
    }
    await prefs.setBool(_keyMembroClube, ehMembroClube);
  }

  // 📥 Carregar dados salvos
  static Future<Map<String, dynamic>> carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token': prefs.getString(_keyToken) ?? '',
      'clienteId': prefs.getInt(_keyClienteId) ?? 0,
      'clienteNome': prefs.getString(_keyClienteNome) ?? '',
      'cpfCliente': prefs.getString(_keyCpfCliente),
      'ehMembroClube': prefs.getBool(_keyMembroClube) ?? false,
    };
  }

  // 🏷️ Atualizar apenas os dados do Clube (CPF e Membro) após vincular
  static Future<void> salvarClube(String cpf, bool ehMembro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCpfCliente, cpf);
    await prefs.setBool(_keyMembroClube, ehMembro);
  }

  // 🚪 Limpar sessão (Logout)
  static Future<void> limparSessao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
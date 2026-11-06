import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_admin_screen.dart';
import 'fila_pedidos_separador_screen.dart'; // Certifique-se de que o caminho do import está correto para a sua tela

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Verifica se já existe uma sessão salva localmente
  final prefs = await SharedPreferences.getInstance();
  final String? tokenSalvo = prefs.getString('auth_token');
  final String? nomeSalvo = prefs.getString('nome_separador');

  const String baseUrl = 'https://box-smart-backend.onrender.com';

  runApp(BoxSmartPortalApp(
    tokenSalvo: tokenSalvo,
    nomeSalvo: nomeSalvo,
    baseUrl: baseUrl,
  ));
}

// ==========================================
// CONFIGURAÇÃO DE CORES E TEMA
// ==========================================
class AppColors {
  static const Color primaria = Color(0xFF2E7D32); // Verde Esmeralda Forte
  static const Color primariaClara = Color(0xFF81C784);
  static const Color primariaMuitoClara = Color(0xFFE8F5E9);
  static const Color destaque = Color(0xFFda251c);
  static const Color fundo = Color(0xFFFFFFFF);
  static const Color textoPrincipal = Color(0xFF212121);
  static const Color textoSecundario = Color(0xFF757575);
}

class BoxSmartPortalApp extends StatelessWidget {
  final String? tokenSalvo;
  final String? nomeSalvo;
  final String baseUrl;

  const BoxSmartPortalApp({
    Key? key,
    this.tokenSalvo,
    this.nomeSalvo,
    required this.baseUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Se houver token e nome salvos, redireciona direto para a fila de separação
    final bool jaEstaLogado = tokenSalvo != null &&
        tokenSalvo!.isNotEmpty &&
        nomeSalvo != null &&
        nomeSalvo!.isNotEmpty;

    return MaterialApp(
      title: 'Box Smart - Portal Gestão',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: jaEstaLogado
          ? FilaPedidosSeparadorScreen(
        baseUrl: baseUrl,
        token: tokenSalvo!,
        nomeSeparador: nomeSalvo!,
      )
          : LoginAdminScreen(baseUrl: baseUrl),
    );
  }
}
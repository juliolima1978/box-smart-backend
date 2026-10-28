import 'package:flutter/material.dart';
import 'login_admin_screen.dart';

void main() {
  runApp(const BoxSmartPortalApp());
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
  const BoxSmartPortalApp({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    // Altere para o IP/porta do seu backend FastAPI
    const String baseUrl = 'https://box-smart-backend.onrender.com';

    return MaterialApp(
      title: 'Box Smart - Portal Gestão',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginAdminScreen(baseUrl: baseUrl),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_portal_screen.dart';
import 'fila_pedidos_separador_screen.dart';

class LoginAdminScreen extends StatefulWidget {
  final String baseUrl;

  const LoginAdminScreen({Key? key, required this.baseUrl}) : super(key: key);

  @override
  _LoginAdminScreenState createState() => _LoginAdminScreenState();
}

class _LoginAdminScreenState extends State<LoginAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'senha': _senhaController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        print('Resposta do Login: $data');

        final String token = data['access_token'] ?? '';
        final String perfil = (data['perfil'] ?? data['role'] ?? 'cliente').toString().toLowerCase();
        final String nomeApi = (data['nome'] ?? (data['usuario'] is Map ? data['usuario']['nome'] : null) ?? '').toString().trim();
        final String nomeUsuario = nomeApi.isNotEmpty ? nomeApi : _emailController.text.split('@')[0];

        const perfisPermitidos = ['admin', 'gestor', 'separador', 'entregador'];

        if (perfisPermitidos.contains(perfil)) {
          // 🌟 SALVA COM AS CHAVES PADRONIZADAS PARA O MAIN.DART RECONHECER
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('nome_separador', nomeUsuario);
          await prefs.setString('user_perfil', perfil);

          if (!mounted) return;

          // 🌟 REDIRECIONAMENTO ESPECÍFICO PARA SEPARADOR OU ADMIN/GESTOR
          if (perfil == 'separador') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FilaPedidosSeparadorScreen(
                  baseUrl: widget.baseUrl,
                  token: token,
                  nomeSeparador: nomeUsuario,
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AdminPortalScreen(
                  baseUrl: widget.baseUrl,
                  token: token,
                ),
              ),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'Acesso negado. A conta ($perfil) não possui permissão operacional.';
          });
        }
      } else {
        String mensagemErroApi = 'E-mail ou senha incorretos.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['detail'] != null) {
            mensagemErroApi = errorData['detail'].toString();
          }
        } catch (_) {}

        setState(() {
          _errorMessage = mensagemErroApi;
        });
      }
    } catch (e, stack) {
      debugPrint('Erro detalhado no login: $e');
      debugPrint('Stacktrace: $stack');

      setState(() {
        _errorMessage = 'Falha ao conectar com o servidor. Verifique sua conexão.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.admin_panel_settings, size: 64, color: Color(0xFF1E3A8A)),
                const SizedBox(height: 16),
                const Text(
                  'Box Smart - Gestão',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Entre com suas credenciais de acesso',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 24),

                // Campo de E-mail
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) => value!.isEmpty ? 'Informe o e-mail' : null,
                ),
                const SizedBox(height: 16),

                // Campo de Senha
                TextFormField(
                  controller: _senhaController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, informe a sua senha.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mensagem de Erro (se houver)
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Botão de Entrar
                ElevatedButton(
                  onPressed: _isLoading ? null : _fazerLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Acessar Painel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
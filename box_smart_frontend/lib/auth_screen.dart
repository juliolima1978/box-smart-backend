//import 'app_colors.dart'; // Ajuste o caminho se necessário para o seu main.dart
import 'package:box_smart_frontend/screens/esqueci_senha_screen.dart';
import 'package:box_smart_frontend/screens/home_screen.dart';
import 'package:box_smart_frontend/screens/painel/admin_portal_screen.dart';
import 'package:box_smart_frontend/screens/painel/fila_pedidos_separador_screen.dart';
import 'package:box_smart_frontend/services/session_service.dart'; // 👈 Import do SessionService
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart'; // Importante para acessar a HomeScreen e AppColors

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true; // Controla se estamos a mostrar Login ou Cadastro
  bool _carregando = false;
  bool _obscurePassword = true; // Para alternar visibilidade da senha
  final String baseUrl = "http://192.168.15.175:8000";

  // Controladores de Login
  final _loginEmailController = TextEditingController();
  final _loginSenhaController = TextEditingController();

  // Controladores de Cadastro
  final _cadNomeController = TextEditingController();
  final _cadEmailController = TextEditingController();
  final _cadSenhaController = TextEditingController();
  final _cadTelefoneController = TextEditingController();

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: erro ? Colors.redAccent.shade700 : AppColors.primaria,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
      ),
    );
  }

  Future<void> _fazerLogin() async {
    setState(() => _carregando = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _loginEmailController.text.trim(),
          'senha': _loginSenhaController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        String token = dados['access_token'];

        String perfil = (dados['perfil'] ?? 'cliente').toString().toLowerCase();

        if (!mounted) return;

        if (perfil == 'admin' || perfil == 'gestor') {
          // Salva sessão do admin
          await SessionService.salvarSessao(
            token: token,
            clienteId: 0,
            clienteNome: 'Administrador',
          );

          _mostrarMensagem("Login efetuado com sucesso!");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminPortalScreen(
                baseUrl: baseUrl,
                token: token,
              ),
            ),
          );
        } else if (perfil == 'separador') {
          // Salva sessão do separador
          await SessionService.salvarSessao(
            token: token,
            clienteId: 0,
            clienteNome: 'Separador',
          );

          _mostrarMensagem("Login efetuado com sucesso!");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => FilaPedidosSeparadorScreen(
                baseUrl: baseUrl,
                token: token,
              ),
            ),
          );
        } else {
          final clienteResponse = await http.get(
            Uri.parse('$baseUrl/clientes/'),
            headers: {'Authorization': 'Bearer $token'},
          );

          if (clienteResponse.statusCode == 200) {
            List clientes = jsonDecode(clienteResponse.body);
            final emailDigitado = _loginEmailController.text.trim().toLowerCase();
            var clienteLogado = clientes.firstWhere(
                  (c) => (c['email'] ?? '').toString().trim().toLowerCase() == emailDigitado,
              orElse: () => null,
            );

            if (clienteLogado != null) {
              final int clienteId = clienteLogado['id'];
              final String clienteNome = clienteLogado['nome'] ?? 'Cliente';
              final String? cpfCliente = clienteLogado['cpf']?.toString();
              final bool ehMembro = clienteLogado['eh_membro_clube'] == true || clienteLogado['eh_membro_clube'] == 1;

              // 💾 Salva a sessão completa do cliente no dispositivo
              await SessionService.salvarSessao(
                token: token,
                clienteId: clienteId,
                clienteNome: clienteNome,
                cpfCliente: cpfCliente,
                ehMembroClube: ehMembro,
              );

              _mostrarMensagem("Login efetuado com sucesso!");

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    clienteId: clienteId,
                    clienteNome: clienteNome,
                    token: token,
                  ),
                ),
              );
            } else {
              _mostrarMensagem("Cliente não localizado na base.", erro: true);
            }
          } else {
            _mostrarMensagem("Erro ao carregar dados do usuário.", erro: true);
          }
        }
      } else {
        _mostrarMensagem("E-mail ou senha incorretos.", erro: true);
      }
    } catch (e) {
      _mostrarMensagem("Erro de conexão: $e", erro: true);
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _fazerCadastro() async {
    setState(() => _carregando = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/clientes/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': _cadNomeController.text.trim(),
          'email': _cadEmailController.text.trim(),
          'senha': _cadSenhaController.text.trim(),
          'telefone': _cadTelefoneController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        _mostrarMensagem("Cadastro realizado! Faça login para continuar.");
        _cadNomeController.clear();
        _cadEmailController.clear();
        _cadSenhaController.clear();
        _cadTelefoneController.clear();
        setState(() => _isLogin = true);
      } else {
        String erroMsg = "Erro ao cadastrar.";
        try {
          erroMsg = jsonDecode(response.body)['detail'] ?? erroMsg;
        } catch (_) {}
        _mostrarMensagem(erroMsg, erro: true);
      }
    } catch (e) {
      _mostrarMensagem("Erro de conexão: $e", erro: true);
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- LOGOTIPO & CABEÇALHO ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade100, width: 2),
                  ),
                  child: Image.asset(
                    'assets/logogimptesc.png',
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.shopping_bag_outlined,
                      size: 70,
                      color: AppColors.primaria,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isLogin ? 'Seja Bem-vindo!' : 'Crie sua conta',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Faça login para acessar super ofertas!'
                      : 'Junte-se ao Clube e economize nas compras',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 32),

                // --- FORMULÁRIO (COM CARD ELEVADO SUTIL) ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isLogin ? _buildLoginForm() : _buildRegisterForm(),
                  ),
                ),

                const SizedBox(height: 28),

                // --- BOTÃO DE AÇÃO PRINCIPAL ---
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _carregando ? null : (_isLogin ? _fazerLogin : _fazerCadastro),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaria,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _carregando
                        ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : Text(
                      _isLogin ? 'ENTRAR' : 'CRIAR CONTA',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // --- BOTÃO ALTERNAR TELA ---
                TextButton(
                  onPressed: _carregando ? null : () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      text: _isLogin ? 'Ainda não tem conta? ' : 'Já tem uma conta? ',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      children: [
                        TextSpan(
                          text: _isLogin ? 'Cadastre-se' : 'Faça Login',
                          style: TextStyle(
                            color: AppColors.primaria,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey("login"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _loginEmailController,
          label: 'E-mail',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _loginSenhaController,
          label: 'Senha',
          icon: Icons.lock_outline,
          obscureText: _obscurePassword,
          isPassword: true,
        ),
        const SizedBox(height: 6),
        // 🌟 BOTÃO ESQUECI MINHA SENHA ADICIONADO AQUI
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EsqueciSenhaScreen(baseUrl: baseUrl),
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Esqueceu sua senha?',
              style: TextStyle(
                color: AppColors.primaria,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      key: const ValueKey("register"),
      children: [
        _buildTextField(
          controller: _cadNomeController,
          label: 'Nome Completo',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _cadEmailController,
          label: 'E-mail',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _cadSenhaController,
          label: 'Senha (mínimo 6 caracteres)',
          icon: Icons.lock_outline,
          obscureText: _obscurePassword,
          isPassword: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _cadTelefoneController,
          label: 'Telefone',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    // ... mesmo código do textfield
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: AppColors.primaria, size: 20),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey.shade500,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        )
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primaria, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}
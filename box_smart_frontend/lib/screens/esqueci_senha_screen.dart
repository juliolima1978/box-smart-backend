import 'package:box_smart_frontend/screens/redefinir_senha_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EsqueciSenhaScreen extends StatefulWidget {
  final String baseUrl;
  const EsqueciSenhaScreen({super.key, required this.baseUrl});

  @override
  State<EsqueciSenhaScreen> createState() => _EsqueciSenhaScreenState();
}

class _EsqueciSenhaScreenState extends State<EsqueciSenhaScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _enviando = false;

  Future<void> _solicitarRecuperacao() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um e-mail válido.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/auth/esqueci-senha'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        // Navega para a tela de redefinição passando o e-mail preenchido
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RedefinirSenhaScreen(
              baseUrl: widget.baseUrl,
              emailPreenchido: email,
            ),
          ),
        );
      } else {
        final erro = json.decode(response.body);
        _mostrarErro(erro['detail'] ?? 'Erro ao solicitar recuperação.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar Senha')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esqueceu sua senha?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Digite o e-mail cadastrado na sua conta para receber o código de redefinição.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail cadastrado',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                onPressed: _enviando ? null : _solicitarRecuperacao,
                child: _enviando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Enviar Código', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
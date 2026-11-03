import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ConfiguracoesAppBarScreen extends StatefulWidget {
  final String token;
  final String baseUrl;

  const ConfiguracoesAppBarScreen({
    super.key,
    required this.token,
    required this.baseUrl,
  });

  @override
  State<ConfiguracoesAppBarScreen> createState() => _ConfiguracoesAppBarScreenState();
}

class _ConfiguracoesAppBarScreenState extends State<ConfiguracoesAppBarScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores dos campos do formulário
  final TextEditingController _corFundoController = TextEditingController();
  final TextEditingController _corIconesController = TextEditingController();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _logoUrlController = TextEditingController();

  bool _exibirLogo = false;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoesAtuais();
  }

  // 1. Busca as configurações atuais do backend
  Future<void> _carregarConfiguracoesAtuais() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/configuracoes-app'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _corFundoController.text = data['appbar_cor_fundo'] ?? '#0F172A';
          _corIconesController.text = data['appbar_cor_icones'] ?? '#FFFFFF';
          _tituloController.text = data['appbar_titulo_texto'] ?? 'Box Smart';
          _exibirLogo = data['appbar_exibir_logo'] ?? false;
          _logoUrlController.text = data['appbar_logo_url'] ?? '';
          _carregando = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar configurações: $e');
      if (mounted) setState(() => _carregando = false);
    }
  }

  // 2. Envia as alterações para o backend salvar no banco
  Future<void> _salvarConfiguracoes() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/api/admin/configuracoes-app'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          "appbar_cor_fundo": _corFundoController.text.trim(),
          "appbar_cor_icones": _corIconesController.text.trim(),
          "appbar_titulo_texto": _tituloController.text.trim(),
          "appbar_exibir_logo": _exibirLogo,
          "appbar_logo_url": _logoUrlController.text.trim(),
        }),
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações da AppBar atualizadas com sucesso! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Erro ao salvar no servidor.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar AppBar do Aplicativo'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aparência da Barra Superior (AppBar)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Essas alterações refletem em tempo real no aplicativo dos clientes.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const Divider(height: 30),

                  // Título da AppBar
                  TextFormField(
                    controller: _tituloController,
                    decoration: const InputDecoration(
                      labelText: 'Título da AppBar',
                      border: OutlineInputBorder(),
                      hintText: 'Ex: Box Smart',
                    ),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),

                  // Cor de Fundo
                  TextFormField(
                    controller: _corFundoController,
                    decoration: const InputDecoration(
                      labelText: 'Cor de Fundo (Hexadecimal)',
                      border: OutlineInputBorder(),
                      hintText: 'Ex: #0F172A',
                    ),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),

                  // Cor dos Ícones/Textos
                  TextFormField(
                    controller: _corIconesController,
                    decoration: const InputDecoration(
                      labelText: 'Cor dos Ícones e Textos (Hexadecimal)',
                      border: OutlineInputBorder(),
                      hintText: 'Ex: #FFFFFF',
                    ),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),

                  // Switch para exibir logo
                  SwitchListTile(
                    title: const Text('Exibir imagem de Logo em vez do Título de Texto'),
                    value: _exibirLogo,
                    onChanged: (val) => setState(() => _exibirLogo = val),
                  ),
                  const SizedBox(height: 16),

                  // URL da Logo (se o switch estiver ativo)
                  if (_exibirLogo) ...[
                    TextFormField(
                      controller: _logoUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL da Logo',
                        border: OutlineInputBorder(),
                        hintText: 'https://seusite.com/logo.png',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 24),

                  // Botão de Salvar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _salvando ? null : _salvarConfiguracoes,
                      child: _salvando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        'Salvar Configurações',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
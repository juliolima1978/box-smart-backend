import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GerenciarUsuariosTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const GerenciarUsuariosTab({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<GerenciarUsuariosTab> createState() => _GerenciarUsuariosTabState();
}

class _GerenciarUsuariosTabState extends State<GerenciarUsuariosTab> {
  List<dynamic> _usuarios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  Future<void> _carregarUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/usuarios'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _usuarios = jsonDecode(response.body);
        });
      } else {
        _mostrarErro('Erro ao carregar colaboradores: ${response.statusCode}');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _exibirFormularioNovoUsuario() {
    final nomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    String perfilSelecionado = 'separador'; // Padrão

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Novo Colaborador 👤', style: TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Cadastre um novo operador de estoque (separador) ou administrador para o sistema.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome Completo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'E-mail de Acesso',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: senhaCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Senha Provisória',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: telefoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Telefone / WhatsApp (Opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: perfilSelecionado,
                        decoration: const InputDecoration(
                          labelText: 'Perfil de Acesso',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'separador', child: Text('Separador de Estoque')),
                          DropdownMenuItem(value: 'admin', child: Text('Administrador / Gestor')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setStateDialog(() => perfilSelecionado = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () async {
                    if (nomeCtrl.text.trim().isEmpty ||
                        emailCtrl.text.trim().isEmpty ||
                        senhaCtrl.text.trim().isEmpty) {
                      _mostrarErro('Preencha os campos obrigatórios.');
                      return;
                    }

                    try {
                      final response = await http.post(
                        Uri.parse('${widget.baseUrl}/admin/usuarios/'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer ${widget.token}',
                        },
                        body: jsonEncode({
                          'nome': nomeCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'senha': senhaCtrl.text.trim(),
                          'telefone': telefoneCtrl.text.trim().isEmpty ? null : telefoneCtrl.text.trim(),
                          'perfil': perfilSelecionado,
                        }),
                      );

                      if (response.statusCode == 201 || response.statusCode == 200) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Colaborador cadastrado com sucesso!'), backgroundColor: Colors.green),
                        );
                        _carregarUsuarios();
                      } else {
                        final erroBody = jsonDecode(response.body);
                        _mostrarErro(erroBody['detail'] ?? 'Erro ao cadastrar usuário.');
                      }
                    } catch (e) {
                      _mostrarErro('Erro de conexão: $e');
                    }
                  },
                  child: const Text('Salvar Colaborador', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: Colors.red.shade900));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gestão de Usuários & Colaboradores', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: _exibirFormularioNovoUsuario,
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text('Novo Colaborador', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _usuarios.isEmpty
                ? const Center(child: Text('Nenhum colaborador encontrado.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                itemCount: _usuarios.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) {
                  final user = _usuarios[index];
                  final bool isAdmin = user['perfil'] == 'admin' || user['is_admin'] == true;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor: isAdmin ? Colors.purple.shade100 : Colors.blue.shade100,
                      child: Icon(
                        isAdmin ? Icons.admin_panel_settings : Icons.inventory_2,
                        color: isAdmin ? Colors.purple.shade800 : Colors.blue.shade800,
                      ),
                    ),
                    title: Text(user['nome'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(user['email'], style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 4),
                        Chip(
                          label: Text(
                            isAdmin ? 'Administrador' : 'Separador de Estoque',
                            style: TextStyle(
                              fontSize: 11,
                              color: isAdmin ? Colors.purple.shade900 : Colors.blue.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: isAdmin ? Colors.purple.shade50 : Colors.blue.shade50,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
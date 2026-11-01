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
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  // 1. Carrega lista de usuários da API
  Future<void> _carregarUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/usuarios'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _usuarios = jsonDecode(response.body) ?? [];
          _isLoading = false;
        });
      } else {
        _mostrarSnackBar('Erro ao carregar lista de usuários.', eErro: true);
      }
    } catch (e) {
      _mostrarSnackBar('Erro de conexão: $e', eErro: true);
    }
  }

  // 2. Alterna status de Ativo/Inativo
  Future<void> _alternarStatusUsuario(int id, bool statusAtual) async {
    final novoStatus = !statusAtual;
    try {
      final response = await http.patch(
        Uri.parse('${widget.baseUrl}/admin/usuarios/$id/status'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ativo': novoStatus}),
      );

      if (response.statusCode == 200) {
        _mostrarSnackBar(novoStatus ? 'Usuário ativado com sucesso!' : 'Usuário inativado!');
        _carregarUsuarios();
      } else {
        _mostrarSnackBar('Erro ao alterar status do usuário.', eErro: true);
      }
    } catch (e) {
      _mostrarSnackBar('Erro de conexão: $e', eErro: true);
    }
  }

  // 3. Exclui o usuário do sistema
  Future<void> _excluirUsuario(int id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Confirmar Exclusão'),
          ],
        ),
        content: Text('Deseja realmente remover o usuário "$nome"? Esta ação não poderá ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${widget.baseUrl}/admin/usuarios/$id/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _mostrarSnackBar('Usuário excluído com sucesso!');
        _carregarUsuarios();
      } else {
        _mostrarSnackBar('Erro ao excluir usuário.', eErro: true);
      }
    } catch (e) {
      _mostrarSnackBar('Erro de conexão: $e', eErro: true);
    }
  }

  // 4. Modal para Novo Cadastro de Usuário
  void _abrirModalNovoUsuario() {
    final nomeController = TextEditingController();
    final emailController = TextEditingController();
    final senhaController = TextEditingController();
    String perfilSelecionado = 'separador';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Cadastrar Novo Usuário', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome Completo',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: senhaController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: perfilSelecionado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Perfil de Acesso',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'gestor', child: Text('Gestor / Admin', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'separador', child: Text('Separador', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'entregador', child: Text('Entregador', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (novoValor) {
                        if (novoValor != null) {
                          setModalState(() {
                            perfilSelecionado = novoValor;
                          });
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (nomeController.text.isEmpty || emailController.text.isEmpty || senhaController.text.isEmpty) {
                    _mostrarSnackBar('Preencha todos os campos.', eErro: true);
                    return;
                  }

                  Navigator.pop(context);

                  try {
                    final response = await http.post(
                      Uri.parse('${widget.baseUrl}/admin/usuarios/'),
                      headers: {
                        'Authorization': 'Bearer ${widget.token}',
                        'Content-Type': 'application/json',
                      },
                      body: jsonEncode({
                        'nome': nomeController.text.trim(),
                        'email': emailController.text.trim(),
                        'senha': senhaController.text,
                        'perfil': perfilSelecionado,
                        'ativo': true,
                      }),
                    );

                    if (response.statusCode == 201 || response.statusCode == 200) {
                      _mostrarSnackBar('Usuário cadastrado com sucesso!');
                      _carregarUsuarios();
                    } else {
                      _mostrarSnackBar('Erro ao cadastrar usuário.', eErro: true);
                    }
                  } catch (e) {
                    _mostrarSnackBar('Erro de conexão: $e', eErro: true);
                  }
                },
                child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarSnackBar(String msg, {bool eErro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: eErro ? Colors.red.shade800 : Colors.green.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuariosFiltrados = _usuarios.where((u) {
      if (_termoBusca.isEmpty) return true;
      final nome = (u['nome'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final perfil = (u['perfil'] ?? '').toString().toLowerCase();
      return nome.contains(_termoBusca) || email.contains(_termoBusca) || perfil.contains(_termoBusca);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabeçalho Responsivo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gerenciamento de Perfis e Equipe',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.4),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Controle de acessos, permissões e status dos colaboradores.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                label: const Text('Novo Usuário', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _abrirModalNovoUsuario,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Busca e Ações
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome, e-mail ou cargo...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5)),
                    ),
                    onChanged: (val) => setState(() => _termoBusca = val.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155)),
                  onPressed: _carregarUsuarios,
                  tooltip: 'Atualizar Lista',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Lista / Tabela de Usuários Blindada contra Overflow
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                  : usuariosFiltrados.isEmpty
                  ? const Center(child: Text('Nenhum usuário encontrado.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)))
                  : ListView.separated(
                itemCount: usuariosFiltrados.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final u = usuariosFiltrados[index];
                  final int id = u['id'] ?? 0;
                  final String nome = u['nome'] ?? 'Sem nome';
                  final String email = u['email'] ?? 'Sem e-mail';
                  final String perfil = (u['perfil'] ?? 'separador').toString().toLowerCase();
                  final bool ativo = u['ativo'] ?? u['is_active'] ?? true;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _corPerfilBg(perfil),
                          child: Icon(_iconePerfil(perfil), color: _corPerfilIcone(perfil), size: 20),
                        ),
                        const SizedBox(width: 12),

                        // Informações do Usuário Flexíveis
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    nome,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _corPerfilBg(perfil),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      perfil.toUpperCase(),
                                      style: TextStyle(color: _corPerfilIcone(perfil), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (!ativo)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'INATIVO',
                                        style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Ações protegidas em Row compacta
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 32,
                              width: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  ativo ? Icons.block_outlined : Icons.check_circle_outline,
                                  color: ativo ? Colors.orange.shade800 : Colors.green.shade800,
                                  size: 18,
                                ),
                                tooltip: ativo ? 'Inativar Usuário' : 'Ativar Usuário',
                                onPressed: () => _alternarStatusUsuario(id, ativo),
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              height: 32,
                              width: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                tooltip: 'Excluir Usuário',
                                onPressed: () => _excluirUsuario(id, nome),
                              ),
                            ),
                          ],
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

  Color _corPerfilBg(String perfil) {
    switch (perfil) {
      case 'admin':
      case 'gestor':
        return Colors.blue.shade50;
      case 'entregador':
        return Colors.orange.shade50;
      case 'separador':
      default:
        return Colors.purple.shade50;
    }
  }

  Color _corPerfilIcone(String perfil) {
    switch (perfil) {
      case 'admin':
      case 'gestor':
        return Colors.blue.shade800;
      case 'entregador':
        return Colors.orange.shade800;
      case 'separador':
      default:
        return Colors.purple.shade800;
    }
  }

  IconData _iconePerfil(String perfil) {
    switch (perfil) {
      case 'admin':
      case 'gestor':
        return Icons.admin_panel_settings_outlined;
      case 'entregador':
        return Icons.delivery_dining_outlined;
      case 'separador':
      default:
        return Icons.inventory_2_outlined;
    }
  }
}
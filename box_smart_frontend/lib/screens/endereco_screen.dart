import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart'; // Para acessar AppColors
import 'novo_endereco_screen.dart';

class EnderecoScreen extends StatefulWidget {
  final int clienteId;
  final String token;
  final String baseUrl;

  const EnderecoScreen({
    super.key,
    required this.clienteId,
    required this.token,
    required this.baseUrl,
  });

  @override
  State<EnderecoScreen> createState() => _EnderecoScreenState();
}

class _EnderecoScreenState extends State<EnderecoScreen> {
  List<dynamic> _enderecos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarEnderecos();
  }

  // ==========================================
  // 🛡️ POLÍTICA DE AUTENTICAÇÃO
  // ==========================================
  bool _exigirAutenticacao(BuildContext context) {
    if (widget.token.trim().isEmpty || widget.token == 'null') {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Faça login para cadastrar e gerenciar seus endereços!'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _buscarEnderecos() async {
    // 🛑 Se for convidado, cancela a chamada à API
    if (widget.token.trim().isEmpty || widget.token == 'null') {
      setState(() => _carregando = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/clientes/${widget.clienteId}/enderecos'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _enderecos = json.decode(response.body);
          _carregando = false;
        });
      } else {
        setState(() => _carregando = false);
      }
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  // 🗑️ Função para excluir o endereço via API
  Future<void> _excluirEndereco(int enderecoId) async {
    try {
      final response = await http.delete(
        Uri.parse('${widget.baseUrl}/api/enderecos/$enderecoId'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          _enderecos.removeWhere((end) => end['id'] == enderecoId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Endereço excluído com sucesso!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao excluir endereço.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro de conexão ao excluir.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool ehConvidado = widget.token.trim().isEmpty || widget.token == 'null';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Endereços'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ehConvidado
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Acesse sua conta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Faça login para cadastrar e selecionar seus endereços de entrega.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      )
          : _enderecos.isEmpty
          ? const Center(
        child: Text(
          'Nenhum endereço cadastrado.',
          style: TextStyle(color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _enderecos.length,
        itemBuilder: (context, index) {
          final end = _enderecos[index];
          // 🛠️ Correção da quebra de linha na string do endereço
          final enderecoCompleto =
              '${end['rua']}, ${end['numero']}\n${end['bairro']}, ${end['cidade']}/${end['uf']}';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.location_on,
                color: AppColors.primaria,
              ),
              title: Text(
                end['rua'] ?? end['logradouro'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(enderecoCompleto),
              // 🗑️ Botão de exclusão com diálogo de confirmação
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Excluir Endereço'),
                      content: const Text('Deseja realmente remover este endereço?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _excluirEndereco(end['id']);
                          },
                          child: const Text(
                            'Excluir',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              onTap: () {
                // Retorna o Map 'end' inteiro ao selecionar
                Navigator.pop(context, end);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaria,
        onPressed: () async {
          // 🛑 Bloqueia usuários convidados antes de abrir formulário
          if (!_exigirAutenticacao(context)) return;

          final sucesso = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NovoEnderecoScreen(
                clienteId: widget.clienteId,
                token: widget.token,
                baseUrl: widget.baseUrl,
              ),
            ),
          );

          // Recarrega a lista se um endereço for adicionado com sucesso
          if (sucesso == true) {
            setState(() {
              _carregando = true;
            });
            _buscarEnderecos();
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
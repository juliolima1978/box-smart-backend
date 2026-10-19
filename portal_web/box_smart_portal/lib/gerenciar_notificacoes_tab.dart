import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GerenciarNotificacoesTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const GerenciarNotificacoesTab({Key? key, required this.baseUrl, required this.token}) : super(key: key);

  @override
  State<GerenciarNotificacoesTab> createState() => _GerenciarNotificacoesTabState();
}

class _GerenciarNotificacoesTabState extends State<GerenciarNotificacoesTab> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _mensagemController = TextEditingController();
  final _clienteIdController = TextEditingController();
  String _tipoSelecionado = 'alerta';

  bool _enviando = false;
  bool _carregandoHistorico = true;
  List<dynamic> _historico = [];

  @override
  void initState() {
    super.initState();
    _buscarHistorico();
  }


  Future<void> _excluirNotificacao(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Notificação?'),
        content: const Text('Isso removerá a notificação permanentemente do aplicativo dos clientes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${widget.baseUrl}/admin/notificacoes/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificação excluída!'), backgroundColor: Colors.green),
        );
        _buscarHistorico(); // Atualiza a lista na tela imediatamente
      }
    } catch (e) {
      debugPrint('Erro ao excluir: $e');
    }
  }

  Future<void> _buscarHistorico() async {
    setState(() => _carregandoHistorico = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/notificacoes'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _historico = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar histórico: $e');
    } finally {
      setState(() => _carregandoHistorico = false);
    }
  }

  Future<void> _dispararNotificacao() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/admin/notificacoes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'titulo': _tituloController.text,
          'mensagem': _mensagemController.text,
          'tipo': _tipoSelecionado,
          'cliente_id': _clienteIdController.text.isEmpty ? null : int.tryParse(_clienteIdController.text),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificação enviada!'), backgroundColor: Colors.green),
        );
        _tituloController.clear();
        _mensagemController.clear();
        _clienteIdController.clear();
        _buscarHistorico(); // Atualiza a tabela imediatamente
      }
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      setState(() => _enviando = false);
    }
  }


  String _formatarData(String? dataIso) {
    if (dataIso == null || dataIso.isEmpty) return '';
    try {
      final data = DateTime.parse(dataIso).toLocal(); // toLocal() ajusta para o fuso horário do seu PC
      final dia = data.day.toString().padLeft(2, '0');
      final mes = data.month.toString().padLeft(2, '0');
      final ano = data.year;
      final hora = data.hour.toString().padLeft(2, '0');
      final minuto = data.minute.toString().padLeft(2, '0');

      return '$dia/$mes/$ano às $hora:$minuto';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LADO ESQUERDO: Formulário
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Disparar Nova Campanha', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        TextFormField(
                          controller: _tituloController,
                          decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
                          validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _mensagemController,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Mensagem', border: OutlineInputBorder()),
                          validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _tipoSelecionado,
                                decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'alerta', child: Text('Alerta Geral')),
                                  DropdownMenuItem(value: 'oferta', child: Text('Oferta')),
                                  DropdownMenuItem(value: 'pedido', child: Text('Pedido')),
                                ],
                                onChanged: (value) => setState(() => _tipoSelecionado = value!),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _clienteIdController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'ID Cliente (Opcional)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _enviando ? null : _dispararNotificacao,
                          icon: _enviando
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send, color: Colors.white),
                          label: Text(_enviando ? 'Enviando...' : 'Disparar Notificação', style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 32),

          // LADO DIREITO: Tabela de Histórico
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Histórico de Envios', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Expanded(
                  child: _carregandoHistorico
                      ? const Center(child: CircularProgressIndicator())
                      : Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      itemCount: _historico.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _historico[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item['tipo'] == 'oferta' ? Colors.orange.shade100 : Colors.blue.shade100,
                            child: Icon(
                              item['tipo'] == 'oferta' ? Icons.local_offer : Icons.notifications,
                              color: item['tipo'] == 'oferta' ? Colors.orange : Colors.blue,
                            ),
                          ),
                          title: Text(item['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            item['mensagem'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min, // Para a Row ocupar só o espaço necessário
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item['cliente_id'] != null ? 'Cliente ID: ${item['cliente_id']}' : 'Para Todos',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: item['cliente_id'] != null ? Colors.blue : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatarData(item['data_envio']),
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8), // Espaçamento entre o texto e o botão
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: 'Excluir notificação',
                                onPressed: () => _excluirNotificacao(item['id']),
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
          ),
        ],
      ),
    );
  }
}
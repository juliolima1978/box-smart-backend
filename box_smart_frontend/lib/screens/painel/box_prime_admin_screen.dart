import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BoxPrimeAdminScreen extends StatefulWidget {
  final String token;
  final String baseUrl;

  const BoxPrimeAdminScreen({
    super.key,
    required this.token,
    required this.baseUrl,
  });

  @override
  State<BoxPrimeAdminScreen> createState() => _BoxPrimeAdminScreenState();
}

class _BoxPrimeAdminScreenState extends State<BoxPrimeAdminScreen> {
  bool _carregando = true;
  bool _salvando = false;

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _subtituloController = TextEditingController();
  final TextEditingController _historiaController = TextEditingController();

  List<dynamic> _beneficios = [];

  @override
  void initState() {
    super.initState();
    _carregandoConfiguracoes();
  }

  Future<void> _carregandoConfiguracoes() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/box-prime?cliente_id=0'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _tituloController.text = data['titulo_topo'] ?? '';
          _subtituloController.text = data['subtitulo'] ?? '';
          _historiaController.text = data['historia'] ?? '';
          _beneficios = data['beneficios'] ?? [];
          _carregando = false;
        });
      } else {
        setState(() => _carregando = false);
      }
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  Future<void> _salvarAlteracoes() async {
    setState(() => _salvando = true);
    try {
      final body = {
        "titulo_topo": _tituloController.text,
        "subtitulo": _subtituloController.text,
        "historia": _historiaController.text,
        "beneficios": _beneficios,
      };

      final response = await http.put(
        Uri.parse('${widget.baseUrl}/admin/box-prime'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações do Box Prime salvas com sucesso!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar alterações.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: $e')),
      );
    } finally {
      setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Gerenciar Box Prime (Admin)',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informações do Topo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tituloController,
              decoration: InputDecoration(
                labelText: 'Título Principal',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtituloController,
              decoration: InputDecoration(
                labelText: 'Subtítulo',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'História & Propósito',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _historiaController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Texto descritivo do clube',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _salvando ? null : _salvarAlteracoes,
                child: _salvando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Salvar Alterações',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
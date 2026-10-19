import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart'; // Importa AppColors do Box Smart
import 'package:flutter/services.dart';

class NovoEnderecoScreen extends StatefulWidget {
  final int clienteId;
  final String token;
  final String baseUrl;

  const NovoEnderecoScreen({
    super.key,
    required this.clienteId,
    required this.token,
    required this.baseUrl,
  });

  @override
  State<NovoEnderecoScreen> createState() => _NovoEnderecoScreenState();
}

class _NovoEnderecoScreenState extends State<NovoEnderecoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cepController = TextEditingController();
  final _ruaController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();

  bool _salvando = false;

  Future<void> _salvarEndereco() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    final payload = {
      "rua": _ruaController.text.trim(),
      "numero": _numeroController.text.trim(),
      "complemento": _complementoController.text.trim(),
      "bairro": _bairroController.text.trim(),
      "cidade": _cidadeController.text.trim(),
      "uf": _ufController.text.trim().toUpperCase(),
      "cep": _cepController.text.replaceAll(RegExp(r'[^0-9]'), ''),
      "padrao": false
    };

    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/clientes/${widget.clienteId}/enderecos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pop(context, true); // Retorna indicando sucesso na criação
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar o endereço.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Endereço', style: TextStyle(color: AppColors.textoPrincipal)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _cepController,
              decoration: const InputDecoration(labelText: 'CEP', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CepInputFormatter(), // 👈 Chama o nosso formatador customizado
              ],
              validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ruaController,
              decoration: const InputDecoration(labelText: 'Rua', border: OutlineInputBorder()),
              validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _numeroController,
                    decoration: const InputDecoration(labelText: 'Número', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _complementoController,
                    decoration: const InputDecoration(labelText: 'Complemento (Opcional)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bairroController,
              decoration: const InputDecoration(labelText: 'Bairro', border: OutlineInputBorder()),
              validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _cidadeController,
                    decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _ufController,
                    decoration: const InputDecoration(labelText: 'UF', border: OutlineInputBorder()),
                    maxLength: 2,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaria),
                onPressed: _salvando ? null : _salvarEndereco,
                child: _salvando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Salvar Endereço', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Remove tudo o que não for número
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Trava o limite em 8 dígitos
    if (text.length > 8) return oldValue;

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 2) formatted += '.'; // Adiciona o ponto
      if (i == 5) formatted += '-'; // Adiciona o traço
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
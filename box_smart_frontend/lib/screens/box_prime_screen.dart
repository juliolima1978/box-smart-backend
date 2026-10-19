import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BoxPrimeScreen extends StatefulWidget {
  final int clienteId;
  final String token;
  final String baseUrl;

  const BoxPrimeScreen({
    super.key,
    required this.clienteId,
    required this.token,
    required this.baseUrl,
  });

  @override
  State<BoxPrimeScreen> createState() => _BoxPrimeScreenState();
}

class _BoxPrimeScreenState extends State<BoxPrimeScreen> {
  bool _carregando = true;
  bool _processandoAdesao = false;
  Map<String, dynamic> _dadosPrime = {};

  @override
  void initState() {
    super.initState();
    _buscarDadosPrime();
  }

  // ==========================================
  // 🛡️ POLÍTICA DE AUTENTICAÇÃO
  // ==========================================
  bool _exigirAutenticacao(BuildContext context) {
    if (widget.token.trim().isEmpty || widget.token == 'null') {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Faça login para fazer parte do Clube Box Prime!'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _buscarDadosPrime() async {
    try {
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      if (widget.token.trim().isNotEmpty && widget.token != 'null') {
        headers['Authorization'] = 'Bearer ${widget.token}';
      }

      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/box-prime?cliente_id=${widget.clienteId}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        setState(() {
          _dadosPrime = decoded is Map ? decoded.cast<String, dynamic>() : {};
          _carregando = false;
        });
      } else {
        setState(() {
          _carregando = false;
        });
      }
    } catch (e) {
      setState(() {
        _carregando = false;
      });
    }
  }

  Future<void> _entrarNoClube() async {
    // 🛑 Bloqueia usuários convidados antes de tentar a requisição
    if (!_exigirAutenticacao(context)) return;

    setState(() => _processandoAdesao = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/box-prime/entrar'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({"cliente_id": widget.clienteId}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _dadosPrime['eh_membro'] = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parabéns! Você agora é membro do Box Prime 🌟')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao se cadastrar no clube.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro de conexão ao tentar participar.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processandoAdesao = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String tituloTopo = _dadosPrime['titulo_topo'] ?? _dadosPrime['titulo'] ?? 'Faça parte do Box Prime';
    final String subtitulo = _dadosPrime['subtitulo'] ?? _dadosPrime['descricao_topo'] ?? 'Exclusividade e vantagens criadas para você.';
    final String historia = _dadosPrime['historia'] ?? _dadosPrime['texto_sobre'] ?? 'O Box Prime nasceu com a missão de recompensar nossos clientes mais fiéis. Acreditamos que comprar bem vai além de bons preços: é sobre ter experiências únicas. Por isso, criamos um clube de vantagens totalmente gratuito, sem letras miúdas ou taxas ocultas, garantindo acesso antecipado, brindes e condições especiais.';
    final List beneficios = _dadosPrime['beneficios'] ?? _dadosPrime['lista_beneficios'] ?? [];
    final bool ehMembro = _dadosPrime['eh_membro'] == true;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Clube Box Prime',
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
            // 🌟 Banner de Boas-Vindas Gratuito
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade700, Colors.amber.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '100% GRATUITO',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tituloTopo,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitulo,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 📖 Seção Sobre / História
            const Text(
              'Nossa História & Propósito',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Text(
                historia,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),

            // ✨ Vantagens do Clube (Com Molduras)
            const Text(
              'Seus Benefícios Exclusivos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: beneficios.length,
              itemBuilder: (context, index) {
                final beneficio = beneficios[index] ?? {};

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              beneficio['titulo'] ?? 'Vantagem Exclusiva',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              beneficio['descricao'] ?? beneficio['texto'] ?? '',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // 🚀 Botão Dinâmico de Adesão ou Selo de Membro Ativo
            ehMembro
                ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green.shade700),
                  const SizedBox(width: 10),
                  Text(
                    'Você é um Membro Ativo Box Prime!',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                  ),
                ],
              ),
            )
                : SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                onPressed: _processandoAdesao ? null : _entrarNoClube,
                child: _processandoAdesao
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text(
                  'Quero Participar Gratuitamente',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
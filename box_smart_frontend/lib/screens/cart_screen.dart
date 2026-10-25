import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../auth_screen.dart';
import '../widgets/produto_card.dart';
import '../services/session_service.dart';
import 'checkout_sucesso_screen.dart';
import 'endereco_screen.dart';
import '../main.dart';
import 'produto_detalhe_screen.dart';
import 'checkout_flow_screen.dart';

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 11) text = text.substring(0, 11);

    var formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) formatted += '.';
      if (i == 9) formatted += '-';
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CartScreen extends StatefulWidget {
  final Map<int, int> carrinho;
  final List<dynamic> produtos;
  final int clienteId;
  final String clienteNome;
  final String token;
  final VoidCallback onLimparCarrinho;
  final Set<int>? favoritosIds;
  final Function(int)? onMudarAba;

  const CartScreen({
    super.key,
    required this.carrinho,
    required this.produtos,
    required this.clienteId,
    required this.clienteNome,
    required this.token,
    required this.onLimparCarrinho,
    this.favoritosIds,
    this.onMudarAba,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _processandoPedido = false;
  String _formaPagamento = 'Pix';
  String _tipoEntrega = 'entrega';

  String? _cpfCliente;
  bool _ehMembroClube = false;
  bool _bannerDispensado = false;

  final String baseUrl = "https://box-smart-backend.onrender.com";

  String _enderecoEntrega = 'Endereço não selecionado';
  bool _precisaTroco = false;
  final TextEditingController _trocoController = TextEditingController();

  List<dynamic> _recomendacoes = [];
  bool _carregandoRecomendacoes = false;

  final Set<int> _favoritosLocais = {};
  Set<int> get _favoritosEfetivos => widget.favoritosIds ?? _favoritosLocais;

  // 🚚 VARIÁVEIS DA TAXA DE ENTREGA DINÂMICA
  double _valorFreteCalculado = 7.00;
  double _faltamParaFreteGratis = 0.0;
  bool _freteGratisHoje = false;
  double _valorMinimoFreteGratis = 0;
  bool _carregandoFrete = false;

  int? _enderecoSelecionadoId;

  String _tokenEfetivo = '';
  int _clienteIdEfetivo = 0;

  @override
  void initState() {
    super.initState();
    _tokenEfetivo = widget.token;
    _clienteIdEfetivo = widget.clienteId;

    _carregarSessaoLocalESincronizar();
    _buscarRecomendacoes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calcularFreteBackend();
    });
  }

  Future<void> _carregarSessaoLocalESincronizar() async {
    final sessao = await SessionService.carregarSessao();

    if (mounted) {
      setState(() {
        if (_tokenEfetivo.trim().isEmpty || _tokenEfetivo == 'null') {
          _tokenEfetivo = sessao['token'] ?? '';
        }
        if (_clienteIdEfetivo <= 0) {
          _clienteIdEfetivo = sessao['clienteId'] ?? 0;
        }
        _cpfSessionCheck(sessao);
      });
      _calcularFreteBackend();
    }
  }

  void _cpfSessionCheck(Map<String, dynamic> sessao) {
    if (_cpfCliente == null || _cpfCliente!.isEmpty) {
      final cpfSalvo = sessao['cpfCliente'];
      if (cpfSalvo != null && cpfSalvo.toString().isNotEmpty) {
        _cpfCliente = cpfSalvo;
        _ehMembroClube = sessao['ehMembroClube'] ?? false;
      }
    }
  }

  @override
  void dispose() {
    _trocoController.dispose();
    super.dispose();
  }

  Future<void> _calcularFreteBackend() async {
    final subtotalComDesconto = _subtotalSemDesconto - _totalEconomiaClube;
    if (subtotalComDesconto <= 0) return;

    setState(() => _carregandoFrete = true);

    try {
      String url = '$baseUrl/api/frete/calcular?subtotal=$subtotalComDesconto';
      if (_enderecoSelecionadoId != null) {
        url += '&endereco_id=$_enderecoSelecionadoId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_tokenEfetivo',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dados = json.decode(response.body);
        if (mounted) {
          setState(() {
            _valorFreteCalculado = (dados['valor_frete'] as num).toDouble();
            _faltamParaFreteGratis = (dados['faltam_para_frete_gratis'] as num).toDouble();
            _freteGratisHoje = dados['frete_gratis_hoje'] ?? false;
            _valorMinimoFreteGratis = (dados['valor_minimo_frete_gratis'] as num).toDouble();
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao calcular frete no backend: $e');
    } finally {
      if (mounted) setState(() => _carregandoFrete = false);
    }
  }

  bool _exigirAutenticacao(BuildContext context) {
    if (_tokenEfetivo.trim().isEmpty || _tokenEfetivo == 'null') {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Você precisa estar logado para continuar.'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );

      return false;
    }
    return true;
  }

  void _tratarAcaoVoltar() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else if (widget.onMudarAba != null) {
      widget.onMudarAba!(0);
    }
  }

  void _mostrarDialogoEditarQuantidade(Map<String, dynamic> item) {
    final bool eVariavelPorPeso = item['eVariavelPorPeso'] == true;
    final int produtoId = item['id'];

    final String valorInicial = eVariavelPorPeso
        ? (item['quantidade'] / 1000.0).toStringAsFixed(3).replaceAll('.', ',')
        : item['quantidade'].toString();

    final TextEditingController controller = TextEditingController(text: valorInicial);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            eVariavelPorPeso ? 'Alterar Peso (kg)' : 'Alterar Quantidade',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eVariavelPorPeso
                    ? 'Digite o peso em kg desejado para "${item['nome']}":'
                    : 'Digite a quantidade desejada para "${item['nome']}":',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(decimal: eVariavelPorPeso),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    eVariavelPorPeso ? RegExp(r'[\d.,]') : RegExp(r'\d'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: eVariavelPorPeso ? 'Peso (ex: 0,500 kg)' : 'Quantidade',
                  suffixText: eVariavelPorPeso ? 'kg' : 'un',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaria,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final textoFormatado = controller.text.replaceAll(',', '.').trim();

                if (eVariavelPorPeso) {
                  final double? pesoKg = double.tryParse(textoFormatado);
                  if (pesoKg != null && pesoKg > 0) {
                    final int gramas = (pesoKg * 1000).round();
                    setState(() {
                      widget.carrinho[produtoId] = gramas;
                    });
                    Navigator.pop(dialogContext);
                    _buscarRecomendacoes();
                    _calcularFreteBackend();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor, informe um peso válido acima de 0 kg.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  final int? qtd = int.tryParse(textoFormatado);
                  if (qtd != null && qtd > 0) {
                    setState(() {
                      widget.carrinho[produtoId] = qtd;
                    });
                    Navigator.pop(dialogContext);
                    _buscarRecomendacoes();
                    _calcularFreteBackend();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor, informe uma quantidade válida.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Salvar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _exibirModalVincularCPF() {
    if (!_exigirAutenticacao(context)) return;

    final TextEditingController cpfController = TextEditingController(text: _cpfCliente ?? '');
    bool enviando = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Clube Box Prime', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Digite seu CPF para ativar descontos exclusivos e vantagens de membro no seu carrinho.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: cpfController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CpfInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'CPF do Cliente',
                      hintText: '000.000.000-00',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: enviando ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaria,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: enviando
                      ? null
                      : () async {
                    setModalState(() => enviando = true);
                    await _vincularCPFBackend(cpfController.text, dialogContext);
                    setModalState(() => enviando = false);
                  },
                  child: enviando
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text(
                    'Vincular CPF',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _vincularCPFBackend(String cpfDigitado, BuildContext dialogContext) async {
    final cpfLimpo = cpfDigitado.replaceAll(RegExp(r'\D'), '');
    if (cpfLimpo.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite um CPF válido com 11 dígitos.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/cliente/vincular-cpf'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_tokenEfetivo',
        },
        body: json.encode({
          'cliente_id': _clienteIdEfetivo,
          'cpf': cpfDigitado,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dados = json.decode(response.body);
        setState(() {
          _cpfCliente = dados['cpf'] ?? cpfDigitado;
          _ehMembroClube = dados['eh_membro_clube'] ?? true;
        });

        _calcularFreteBackend();

        if (dialogContext.mounted) {
          Navigator.pop(dialogContext);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(dados['mensagem'] ?? 'CPF vinculado com sucesso! Descontos ativados.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } else {
        final erro = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(erro['detail'] ?? 'Erro ao vincular CPF.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro de conexão ao vincular CPF: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _buscarRecomendacoes() async {
    if (widget.carrinho.isEmpty) return;

    setState(() => _carregandoRecomendacoes = true);
    try {
      final int produtoBaseId = widget.carrinho.keys.last;

      final response = await http.get(
        Uri.parse('$baseUrl/api/produtos/$produtoBaseId/relacionados'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> dados = json.decode(response.body);

        final recomendacoesFiltradas = dados.where((produto) {
          return !widget.carrinho.keys.any(
                (idItem) => idItem.toString() == produto['id'].toString(),
          );
        }).toList();

        if (mounted) {
          setState(() {
            _recomendacoes = recomendacoesFiltradas;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar recomendações: $e');
    } finally {
      if (mounted) setState(() => _carregandoRecomendacoes = false);
    }
  }

  List<Map<String, dynamic>> get _itensDetalhados {
    List<Map<String, dynamic>> itens = [];

    widget.carrinho.forEach((produtoId, quantidade) {
      if (quantidade > 0) {
        final prod = widget.produtos.firstWhere(
              (p) => p['id'].toString() == produtoId.toString(),
          orElse: () => null,
        );

        if (prod != null) {
          final double precoNormal =
              double.tryParse(prod['preco'].toString().replaceAll(',', '.')) ?? 0.0;

          final dynamic precoClubeRaw = prod['preco_clube'];
          final double precoClube = precoClubeRaw != null
              ? (double.tryParse(precoClubeRaw.toString().replaceAll(',', '.')) ?? 0.0)
              : 0.0;

          final bool temPrecoClubeValido = precoClube > 0 && precoClube < precoNormal;
          final bool temClube = _ehMembroClube && temPrecoClubeValido;

          final bool eVariavelPorPeso =
              prod['variavel_por_peso'] == true ||
                  prod['unidade']?.toString().toLowerCase() == 'kg';

          final double quantidadeFator = eVariavelPorPeso
              ? quantidade / 1000.0
              : quantidade.toDouble();

          final double precoEfetivo = temClube ? precoClube : precoNormal;

          itens.add({
            'id': produtoId,
            'nome': prod['nome'] ?? 'Produto',
            'imagem_url': prod['imagem_url'],
            'unidade': prod['unidade'] ?? 'un',
            'quantidade': quantidade,
            'eVariavelPorPeso': eVariavelPorPeso,
            'preco_normal': precoNormal,
            'preco_clube': precoClube,
            'tem_clube': temClube,
            'preco_efetivo': precoEfetivo,
            'subtotal': precoEfetivo * quantidadeFator,
            'economia': temClube ? (precoNormal - precoClube) * quantidadeFator : 0.0,
          });
        }
      }
    });

    return itens;
  }

  // ⚖️ Verifica se há pelo menos um item vendido por peso no carrinho
  bool get _temItemVariavelPorPeso {
    for (var item in _itensDetalhados) {
      if (item['eVariavelPorPeso'] == true) {
        return true;
      }
    }
    return false;
  }

  double get _economiaPotencialClube {
    double total = 0.0;
    widget.carrinho.forEach((produtoId, quantidade) {
      if (quantidade > 0) {
        final prod = widget.produtos.firstWhere(
              (p) => p['id'].toString() == produtoId.toString(),
          orElse: () => null,
        );
        if (prod != null) {
          final double precoNormal =
              double.tryParse(prod['preco'].toString().replaceAll(',', '.')) ?? 0.0;
          final dynamic precoClubeRaw = prod['preco_clube'];
          if (precoClubeRaw != null) {
            final double precoClube =
                double.tryParse(precoClubeRaw.toString().replaceAll(',', '.')) ?? 0.0;
            if (precoClube > 0 && precoClube < precoNormal) {
              final bool eVariavelPorPeso =
                  prod['variavel_por_peso'] == true ||
                      prod['unidade']?.toString().toLowerCase() == 'kg';
              final double fator = eVariavelPorPeso
                  ? quantidade / 1000.0
                  : quantidade.toDouble();
              total += (precoNormal - precoClube) * fator;
            }
          }
        }
      }
    });
    return total;
  }

  double get _subtotalSemDesconto => _itensDetalhados.fold(
    0.0,
        (sum, item) =>
    sum +
        (item['preco_normal'] *
            (item['eVariavelPorPeso']
                ? item['quantidade'] / 1000.0
                : item['quantidade'])),
  );

  double get _totalEconomiaClube =>
      _itensDetalhados.fold(0.0, (sum, item) => sum + item['economia']);

  double get _taxaEntrega =>
      _tipoEntrega == 'entrega' ? _valorFreteCalculado : 0.0;

  double get _valorTotalFinal =>
      (_subtotalSemDesconto - _totalEconomiaClube) + _taxaEntrega;

  // 🚚 BANNER DE FRETE GRÁTIS DINÂMICO E CORRIGIDO
  Widget _buildBannerProgressoFrete() {
    if (_tipoEntrega != 'entrega') return const SizedBox.shrink();

    final double subtotalLiquido = _subtotalSemDesconto - _totalEconomiaClube;

    if (_freteGratisHoje) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: Colors.green.shade700, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🎉 Hoje o frete é GRÁTIS no Box Smart! Aproveite!',
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 🌟 SÓ EXIBE O BANNER DE PARABÉNS SE REALMENTE ATINGIR OU ULTRAPASSAR O VALOR MÍNIMO
    if (subtotalLiquido >= _valorMinimoFreteGratis) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🎉 Parabéns! Você atingiu o valor mínimo e ganhou FRETE GRÁTIS!',
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Caso contrário, calcula quanto falta para exibir a barra de progresso em amarelo
    final double quantoFalta = (_valorMinimoFreteGratis - subtotalLiquido).clamp(0.0, _valorMinimoFreteGratis);
    final double progresso = (subtotalLiquido / _valorMinimoFreteGratis).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: Colors.amber.shade900, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Faltam R\$ ${quantoFalta.toStringAsFixed(2).replaceAll('.', ',')} para FRETE GRÁTIS!',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 7,
              backgroundColor: Colors.amber.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerBoxPrime() {
    final bool ativo = _ehMembroClube && _cpfCliente != null && _cpfCliente!.isNotEmpty;

    if (ativo) {
      final String cpfFormatado = _cpfCliente!.length == 11
          ? '***.${_cpfCliente!.substring(3, 6)}.${_cpfCliente!.substring(6, 9)}-**'
          : _cpfCliente!;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'CPF $cpfFormatado ativado (Descontos do Clube aplicados)',
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            InkWell(
              onTap: () => _exibirModalVincularCPF(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Alterar',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_bannerDispensado) return const SizedBox.shrink();

    final double economiaPotencial = _economiaPotencialClube;

    if (economiaPotencial > 0) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade800, Colors.amber.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.shade900.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ECONOMIZE R\$ ${economiaPotencial.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Informe seu CPF para ativar os descontos do Clube no seu carrinho!',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.amber.shade900,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _exibirModalVincularCPF(),
                  child: const Text('Ativar CPF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            Positioned(
              right: -4,
              top: -4,
              child: GestureDetector(
                onTap: () {
                  setState(() => _bannerDispensado = true);
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCarrosselRecomendacoes() {
    if (_carregandoRecomendacoes) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaria)),
      );
    }

    if (_recomendacoes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 12.0, bottom: 12.0),
          child: Text(
            'Esqueceu de algo?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recomendacoes.length,
            itemBuilder: (context, index) {
              final produto = _recomendacoes[index];

              return Container(
                width: 165,
                margin: const EdgeInsets.only(right: 12, bottom: 6, top: 4),
                child: ProdutoCard(
                  produto: produto,
                  carrinho: widget.carrinho,
                  favoritosIds: _favoritosEfetivos,
                  produtosListaGlobal: widget.produtos,
                  onCarrinhoAlterado: () {
                    if (mounted) {
                      setState(() {});
                      _buscarRecomendacoes();
                      _calcularFreteBackend();
                    }
                  },
                  onToggleFavorito: (id) async {
                    final favoritos = widget.favoritosIds;
                    if (favoritos != null) {
                      setState(() {
                        if (favoritos.contains(id)) {
                          favoritos.remove(id);
                        } else {
                          favoritos.add(id);
                        }
                      });

                      try {
                        await http.post(
                          Uri.parse('$baseUrl/clientes/$_clienteIdEfetivo/favoritos/$id'),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer $_tokenEfetivo',
                          },
                        );
                      } catch (e) {
                        debugPrint('Erro ao salvar favorito no carrinho: $e');
                      }
                    }
                  },
                  onTapDetalhes: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProdutoDetalheScreen(
                          clienteId: _clienteIdEfetivo,
                          token: _tokenEfetivo,
                          favoritosIds: _favoritosEfetivos,
                          produto: produto,
                          carrinho: widget.carrinho,
                          produtosListaGlobal: widget.produtos,
                        ),
                      ),
                    ).then((_) {
                      if (mounted) {
                        setState(() {});
                        _calcularFreteBackend();
                      }
                    });
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _iniciarCheckoutFlow() {
    if (!_exigirAutenticacao(context)) return;

    if (_itensDetalhados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seu carrinho está vazio!')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutFlowScreen(
          clienteId: _clienteIdEfetivo,
          token: _tokenEfetivo,
          baseUrl: baseUrl,
          carrinho: widget.carrinho,
          produtosListaGlobal: widget.produtos,
          favoritosIds: _favoritosEfetivos,
          clienteNome: widget.clienteNome,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
        _calcularFreteBackend();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final itens = _itensDetalhados;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _tratarAcaoVoltar();
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            'Carrinho e Fechamento',
            style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: _tratarAcaoVoltar,
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87),
          ),
          automaticallyImplyLeading: false,
        ),
        body: itens.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Sua sacola está vazia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              const Text(
                'Adicione produtos na Home para fechar a compra.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaria),
                onPressed: () {
                  if (widget.onMudarAba != null) {
                    widget.onMudarAba!(0);
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Ir para as Ofertas', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        )
            : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBannerProgressoFrete(),
                    _buildBannerBoxPrime(),

                    // ⚖️ PAINEL DE AVISO DE PESO VARIÁVEL AQUI:
                    if (_temItemVariavelPorPeso)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.scale_outlined, color: Colors.amber.shade900, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Atenção: Seu carrinho contém produtos de peso variável. O valor total é uma estimativa e será ajustado exatamente após a pesagem no balcão.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),
                    const Text(
                      'Itens Selecionados',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: itens.length,
                      itemBuilder: (context, index) {
                        final item = itens[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                padding: const EdgeInsets.all(4),
                                child: item['imagem_url'] != null &&
                                    item['imagem_url'].toString().startsWith('http')
                                    ? Image.network(item['imagem_url'], fit: BoxFit.contain)
                                    : const Icon(Icons.shopping_bag, size: 30, color: Colors.grey),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['nome'],
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          item['eVariavelPorPeso']
                                              ? 'R\$ ${item['subtotal'].toStringAsFixed(2).replaceAll('.', ',')}'
                                              : 'R\$ ${item['preco_efetivo'].toStringAsFixed(2).replaceAll('.', ',')}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: item['tem_clube']
                                                ? const Color(0xFFD97706)
                                                : Colors.black87,
                                          ),
                                        ),
                                        if (item['tem_clube']) ...[
                                          Text(
                                            item['eVariavelPorPeso']
                                                ? 'R\$ ${(item['preco_normal'] * (item['quantidade'] / 1000.0)).toStringAsFixed(2).replaceAll('.', ',')}'
                                                : 'R\$ ${item['preco_normal'].toStringAsFixed(2).replaceAll('.', ',')}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'CLUBE',
                                              style: TextStyle(
                                                fontSize: 7,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (item['eVariavelPorPeso']) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${(item['quantidade'] / 1000.0).toStringAsFixed(3).replaceAll('.', ',')} kg × R\$ ${item['preco_efetivo'].toStringAsFixed(2).replaceAll('.', ',')}/kg',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      final String nomeRemovido = item['nome'];
                                      final int idRemovido = item['id'];
                                      final int qtdRemovida = item['quantidade'];

                                      setState(() {
                                        widget.carrinho.remove(idRemovido);
                                      });

                                      _buscarRecomendacoes();
                                      _calcularFreteBackend();

                                      final messenger = ScaffoldMessenger.of(context);
                                      messenger.hideCurrentSnackBar();

                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('$nomeRemovido removido do carrinho'),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          dismissDirection: DismissDirection.horizontal,
                                          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                                          action: SnackBarAction(
                                            label: 'DESFAZER',
                                            textColor: Colors.amber,
                                            onPressed: () {
                                              messenger.hideCurrentSnackBar();
                                              if (!mounted) return;

                                              setState(() {
                                                widget.carrinho[idRemovido] = qtdRemovida;
                                              });

                                              _buscarRecomendacoes();
                                              _calcularFreteBackend();
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0, right: 4.0),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red.shade400,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.remove, size: 16),
                                          onPressed: () {
                                            setState(() {
                                              if (item['eVariavelPorPeso']) {
                                                if (widget.carrinho[item['id']]! > 250) {
                                                  widget.carrinho[item['id']] =
                                                      widget.carrinho[item['id']]! - 250;
                                                } else {
                                                  widget.carrinho.remove(item['id']);
                                                  _buscarRecomendacoes();
                                                }
                                              } else {
                                                if (widget.carrinho[item['id']]! > 1) {
                                                  widget.carrinho[item['id']] =
                                                      widget.carrinho[item['id']]! - 1;
                                                } else {
                                                  widget.carrinho.remove(item['id']);
                                                  _buscarRecomendacoes();
                                                }
                                              }
                                            });
                                            _calcularFreteBackend();
                                          },
                                        ),
                                        InkWell(
                                          onTap: () => _mostrarDialogoEditarQuantidade(item),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Text(
                                              item['eVariavelPorPeso']
                                                  ? '${(item['quantidade'] / 1000.0).toStringAsFixed(3).replaceAll('.', ',')}kg'
                                                  : '${item['quantidade']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                decoration: TextDecoration.underline,
                                                decorationStyle: TextDecorationStyle.dotted,
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.add, size: 16),
                                          onPressed: () {
                                            setState(() {
                                              if (item['eVariavelPorPeso']) {
                                                widget.carrinho[item['id']] =
                                                    widget.carrinho[item['id']]! + 250;
                                              } else {
                                                widget.carrinho[item['id']] =
                                                    widget.carrinho[item['id']]! + 1;
                                              }
                                            });
                                            _calcularFreteBackend();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    _buildCarrosselRecomendacoes(),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal:', style: TextStyle(color: Colors.grey)),
                              Text(
                                'R\$ ${_subtotalSemDesconto.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          if (_totalEconomiaClube > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Desconto Box Prime (CPF):',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '- R\$ ${_totalEconomiaClube.toStringAsFixed(2).replaceAll('.', ',')}',
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Final:',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'R\$ ${(_subtotalSemDesconto - _totalEconomiaClube).toStringAsFixed(2).replaceAll('.', ',')}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaria,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaria,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _processandoPedido ? null : _iniciarCheckoutFlow,
                    child: Text(
                      'Finalizar Pedido • R\$ ${(_subtotalSemDesconto - _totalEconomiaClube).toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
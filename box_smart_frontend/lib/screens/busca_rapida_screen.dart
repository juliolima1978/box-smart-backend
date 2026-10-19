import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'produto_detalhe_screen.dart';
import 'cart_screen.dart';
import 'favorites_screen.dart';
//import 'profile_screen.dart';
import 'notificacoes_screen.dart';
import 'search_screen.dart';
import '../main.dart';

class BuscaRapidaScreen extends StatefulWidget {
  final int clienteId;
  final String token;
  final String baseUrl;
  final Map<int, int> carrinho;
  final Set<int> favoritosIds;
  final List<dynamic> produtosListaGlobal;
  final Function(int)? onMudarAba;

  const BuscaRapidaScreen({
    super.key,
    required this.clienteId,
    required this.token,
    required this.baseUrl,
    required this.carrinho,
    required this.favoritosIds,
    required this.produtosListaGlobal,
    this.onMudarAba,
  });

  @override
  State<BuscaRapidaScreen> createState() => _BuscaRapidaScreenState();
}

class _BuscaRapidaScreenState extends State<BuscaRapidaScreen> {
  final List<TextEditingController> _controllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  final ScrollController _scrollController = ScrollController();

  // Armazena os resultados agrupados: { "termo": [produtos...] }
  Map<String, List<dynamic>> _resultadosBusca = {};
  // Guarda metadados extraídos de cada termo (ex: quantidade/peso inferidos)
  Map<String, Map<String, dynamic>> _metadadosTermos = {};
  bool _buscou = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  // 🧠 FUNÇÃO INTELIGENTE 1: Normalização de texto sem acentos (Corrigida)
  String _normalizarTexto(String texto) {
    const comAcento = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÝýÿñ';
    const semAcento = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuYyyn';

    String resultado = texto;
    for (int i = 0; i < comAcento.length; i++) {
      resultado = resultado.replaceAll(comAcento[i], semAcento[i]);
    }
    return resultado.toLowerCase().trim();
  }

  // 🧠 FUNÇÃO INTELIGENTE 2: Extrai quantidade e peso digitados ("2x Leite", "500g Carne", "1.5kg Batata")
  Map<String, dynamic> _extrairQuantidadeETermo(String entrada) {
    String texto = entrada.trim();

    final regexPesoG = RegExp(r'^(\d+)\s*g\b\s*(.*)$', caseSensitive: false);
    final regexPesoKg = RegExp(r'^([\d.,]+)\s*kg\b\s*(.*)$', caseSensitive: false);
    final regexQtdX = RegExp(r'^(\d+)\s*x\b\s*(.*)$', caseSensitive: false);
    final regexQtdNum = RegExp(r'^(\d+)\s+(.*)$');

    if (regexPesoG.hasMatch(texto)) {
      final match = regexPesoG.firstMatch(texto)!;
      int gramas = int.tryParse(match.group(1)!) ?? 500;
      return {'termo': match.group(2)!, 'quantidade': gramas, 'ePeso': true};
    } else if (regexPesoKg.hasMatch(texto)) {
      final match = regexPesoKg.firstMatch(texto)!;
      double kg = double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 1.0;
      return {'termo': match.group(2)!, 'quantidade': (kg * 1000).round(), 'ePeso': true};
    } else if (regexQtdX.hasMatch(texto)) {
      final match = regexQtdX.firstMatch(texto)!;
      int q = int.tryParse(match.group(1)!) ?? 1;
      return {'termo': match.group(2)!, 'quantidade': q, 'ePeso': false};
    } else if (regexQtdNum.hasMatch(texto)) {
      final match = regexQtdNum.firstMatch(texto)!;
      int q = int.tryParse(match.group(1)!) ?? 1;
      return {'termo': match.group(2)!, 'quantidade': q, 'ePeso': false};
    }

    return {'termo': texto, 'quantidade': 1, 'ePeso': false};
  }

  void _adicionarLinha([String valorInicial = '']) {
    setState(() {
      _controllers.add(TextEditingController(text: valorInicial));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _removerLinha(int index) {
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
  }

  // 🧠 FUNÇÃO INTELIGENTE 3: Importar texto colado do WhatsApp ou Bloco de Notas
  void _mostrarModalColarLista() {
    final TextEditingController importController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.paste_rounded, color: AppColors.primaria),
            SizedBox(width: 8),
            Text('Colar Lista Completa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cole sua lista (uma linha por item ou separada por vírgulas):',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: importController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Ex:\n2x Leite\n500g Carne moída\nPão de açúcar\nFeijão',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaria),
            onPressed: () {
              final texto = importController.text.trim();
              if (texto.isNotEmpty) {
                List<String> linhas = texto
                    .split(RegExp(r'[\n,]'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                if (linhas.isNotEmpty) {
                  setState(() {
                    for (var c in _controllers) {
                      c.dispose();
                    }
                    _controllers.clear();
                    for (var item in linhas) {
                      _controllers.add(TextEditingController(text: item));
                    }
                  });
                  Navigator.pop(ctx);
                  _executarBusca();
                }
              }
            },
            child: const Text('Importar e Buscar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🧠 FUNÇÃO INTELIGENTE 4: Carregar lista pré-definida de sugestão
  void _carregarListaPronta(List<String> itens) {
    setState(() {
      for (var c in _controllers) {
        c.dispose();
      }
      _controllers.clear();
      for (var item in itens) {
        _controllers.add(TextEditingController(text: item));
      }
    });
    _executarBusca();
  }

  void _executarBusca() {
    Map<String, List<dynamic>> resultadosTemp = {};
    Map<String, Map<String, dynamic>> metaTemp = {};

    for (var controller in _controllers) {
      String entradaBruta = controller.text.trim();
      if (entradaBruta.isNotEmpty) {
        final infoExtraida = _extrairQuantidadeETermo(entradaBruta);
        String termoLimpo = infoExtraida['termo'];
        String termoNormalizado = _normalizarTexto(termoLimpo);

        List<dynamic> encontrados = widget.produtosListaGlobal.where((prod) {
          String nomeProd = _normalizarTexto((prod['nome'] ?? '').toString());
          String catProd = _normalizarTexto((prod['categoria'] ?? '').toString());
          return nomeProd.contains(termoNormalizado) || catProd.contains(termoNormalizado);
        }).toList();

        resultadosTemp[entradaBruta] = encontrados;
        metaTemp[entradaBruta] = infoExtraida;
      }
    }

    setState(() {
      _resultadosBusca = resultadosTemp;
      _metadadosTermos = metaTemp;
      _buscou = true;
    });
  }

  // 🧠 FUNÇÃO INTELIGENTE 5: Adicionar o 1º item encontrado de cada termo ao carrinho
  void _adicionarTodosPrimeirosAoCarrinho() {
    int adicionadosCount = 0;

    setState(() {
      _resultadosBusca.forEach((termoOriginal, produtos) {
        if (produtos.isNotEmpty) {
          final primeiroProd = produtos.first;
          final int produtoId = primeiroProd['id'];
          final meta = _metadadosTermos[termoOriginal];

          bool eVariavelPorPeso = primeiroProd['variavel_por_peso'] == true ||
              primeiroProd['unidade']?.toString().toLowerCase() == 'kg';

          int quantidadeFinal = 1;
          if (meta != null) {
            int qtdSugerida = meta['quantidade'] ?? 1;
            if (eVariavelPorPeso) {
              quantidadeFinal = meta['ePeso'] ? qtdSugerida : 1000;
            } else {
              quantidadeFinal = meta['ePeso'] ? 1 : qtdSugerida;
            }
          }

          widget.carrinho[produtoId] = (widget.carrinho[produtoId] ?? 0) + quantidadeFinal;
          adicionadosCount++;
        }
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$adicionadosCount item(ns) adicionado(s) à sua sacola! 🎉'),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(155),
        child: _buildCustomAppBar(),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.black87),
                              SizedBox(width: 4),
                              Text('Voltar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Página Inicial / LISTA RÁPIDA',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'LISTA RÁPIDA',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.caveatBrush(
                        fontSize: 40,
                        color: AppColors.primaria,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 🏷️ ATALHOS DE LISTAS PRONTAS DA SEMANA
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Sugestões: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ActionChip(
                          avatar: const Text('🥩', style: TextStyle(fontSize: 12)),
                          label: const Text('Churrasco', style: TextStyle(fontSize: 11)),
                          onPressed: () => _carregarListaPronta(['Carne', 'Cerveja', 'Carvão', 'Pão de alho', 'Sal grosso']),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Text('☕', style: TextStyle(fontSize: 12)),
                          label: const Text('Café da Manhã', style: TextStyle(fontSize: 11)),
                          onPressed: () => _carregarListaPronta(['Leite', 'Café', 'Pão', 'Manteiga', 'Queijo']),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Text('🧹', style: TextStyle(fontSize: 12)),
                          label: const Text('Limpeza', style: TextStyle(fontSize: 11)),
                          onPressed: () => _carregarListaPronta(['Detergente', 'Sabão em pó', 'Desinfetante', 'Papel higiênico']),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Digite os itens que você procura:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      InkWell(
                        onTap: _mostrarModalColarLista,
                        child: const Row(
                          children: [
                            Icon(Icons.content_paste_go_rounded, size: 14, color: AppColors.primaria),
                            SizedBox(width: 4),
                            Text('Colar Lista', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaria)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _controllers.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: TextField(
                                    controller: _controllers[index],
                                    decoration: InputDecoration(
                                      hintText: 'Ex: 2x Leite, 500g Carne, Pão...',
                                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.only(bottom: 11),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_controllers.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22),
                                  onPressed: () => _removerLinha(index),
                                  tooltip: 'Remover linha',
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => _adicionarLinha(),
                        icon: const Icon(Icons.add, size: 16, color: AppColors.primaria),
                        label: const Text('Adicionar item', style: TextStyle(fontSize: 12, color: AppColors.primaria, fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaria,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: _executarBusca,
                        child: const Text('Buscar Tudo', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            !_buscou
                ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_alt_rounded, size: 50, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Preencha os itens acima ou cole uma lista para buscar tudo de uma vez.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            )
                : _resultadosBusca.isEmpty
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Nenhum termo válido informado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
                : Column(
              children: [
                // 🛒 BOTÃO DE AÇÃO RÁPIDA: Adicionar 1º produto de cada grupo ao carrinho
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
                    label: const Text(
                      'Adicionar 1º produto de cada termo ao Carrinho',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: _adicionarTodosPrimeirosAoCarrinho,
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _resultadosBusca.length,
                  itemBuilder: (context, index) {
                    String termoPesquisado = _resultadosBusca.keys.elementAt(index);
                    List<dynamic> produtos = _resultadosBusca[termoPesquisado]!;
                    final meta = _metadadosTermos[termoPesquisado];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          child: Row(
                            children: [
                              Text(
                                'Resultados para: "$termoPesquisado"',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaria),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${produtos.length})',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              if (meta != null && (meta['quantidade'] > 1 || meta['ePeso'] == true)) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    meta['ePeso'] ? 'Sugerido: ${meta['quantidade']}g' : 'Sugerido: ${meta['quantidade']}x',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        produtos.isEmpty
                            ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: const Text('Nenhum produto encontrado para este item.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        )
                            : SizedBox(
                          height: 260,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: produtos.length,
                            itemBuilder: (context, prodIndex) {
                              return Container(
                                width: 160,
                                margin: const EdgeInsets.only(right: 10, bottom: 8),
                                child: _buildCardProduto(produtos[prodIndex], prodIndex, meta),
                              );
                            },
                          ),
                        ),
                        const Divider(height: 20),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    final int qtdTotalBadge = widget.carrinho.entries.fold<int>(0, (sum, entry) {
      if (entry.value <= 0) return sum;

      final prod = widget.produtosListaGlobal.firstWhere(
            (p) => p['id'].toString() == entry.key.toString(),
        orElse: () => null,
      );

      bool eVariavelPorPeso = false;
      if (prod != null) {
        eVariavelPorPeso = prod['variavel_por_peso'] == true ||
            prod['unidade']?.toString().toLowerCase() == 'kg';
      } else if (entry.value > 50) {
        eVariavelPorPeso = true;
      }

      return sum + (eVariavelPorPeso ? 1 : entry.value);
    });

    return AppBar(
      toolbarHeight: 155,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Image.asset('assets/icones/circle-user (2).png', color: AppColors.primaria, height: 26),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(
                                clienteId: widget.clienteId,
                                token: widget.token,
                              ),
                            ),
                          );
                        },
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            icon: Image.asset('assets/icones/order-history_thin.png', width: 24, height: 24, color: AppColors.primaria, colorBlendMode: BlendMode.srcIn),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CartScreen(
                                    clienteId: widget.clienteId,
                                    token: widget.token,
                                    carrinho: widget.carrinho,
                                    produtos: widget.produtosListaGlobal,
                                    clienteNome: 'Cliente',
                                    onLimparCarrinho: () => setState(() => widget.carrinho.clear()),
                                  ),
                                ),
                              ).then((_) => setState(() {}));
                            },
                          ),
                          if (qtdTotalBadge > 0)
                            Positioned(
                              right: 9,
                              top: 5,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text(
                                  '$qtdTotalBadge',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else if (widget.onMudarAba != null) {
                            widget.onMudarAba!(0);
                          }
                        },
                        child: Image.asset(
                          'assets/logogimptesc.png',
                          height: 75,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text(
                            'BOX SMART',
                            style: TextStyle(
                              color: AppColors.primaria,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Image.asset('assets/icones/heart_thin.png', width: 22, height: 22, color: AppColors.primaria, colorBlendMode: BlendMode.srcIn),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FavoritesScreen(
                                clienteId: widget.clienteId,
                                token: widget.token,
                                baseUrl: widget.baseUrl,
                                carrinho: widget.carrinho,
                                favoritosIds: widget.favoritosIds,
                                produtosListaGlobal: widget.produtosListaGlobal,
                                onAtualizouCarrinho: () => setState(() {}),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Image.asset('assets/icones/bell (1).png', color: AppColors.primaria, height: 22),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotificacoesScreen(
                                clienteId: widget.clienteId,
                                token: widget.token,
                                baseUrl: widget.baseUrl,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  readOnly: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchScreen(
                          clienteId: widget.clienteId,
                          token: widget.token,
                          carrinho: widget.carrinho,
                          favoritosIds: widget.favoritosIds,
                          produtosListaGlobal: widget.produtosListaGlobal,
                        ),
                      ),
                    );
                  },
                  decoration: const InputDecoration(
                    hintText: 'O que você procura hoje?',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardProduto(Map<String, dynamic> prod, int index, Map<String, dynamic>? meta) {
    final double precoNormal = double.tryParse(prod['preco'].toString().replaceAll(',', '.')) ?? 0.0;
    final int produtoId = prod['id'] ?? index;
    final int quantidadeNoCarrinho = widget.carrinho[produtoId] ?? 0;

    final bool eVariavelPorPeso = prod['variavel_por_peso'] == true ||
        prod['unidade']?.toString().toLowerCase() == 'kg';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProdutoDetalheScreen(
              clienteId: widget.clienteId,
              token: widget.token,
              favoritosIds: widget.favoritosIds,
              produto: prod,
              carrinho: widget.carrinho,
              produtosListaGlobal: widget.produtosListaGlobal,
            ),
          ),
        ).then((_) => setState(() {}));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Center(
                child: SizedBox(
                  height: 90,
                  child: prod['imagem_url'] != null && prod['imagem_url'].toString().startsWith('http')
                      ? Image.network(prod['imagem_url'], fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag, size: 40, color: Colors.grey))
                      : const Icon(Icons.shopping_bag, size: 40, color: Colors.grey),
                ),
              ),
              Text(
                prod['nome'] ?? '',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('R\$', style: TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 2),
                  Text(precoNormal.toStringAsFixed(2).replaceAll('.', ','), style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w900)),
                  if (eVariavelPorPeso)
                    const Text('/kg', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              SizedBox(
                width: double.infinity,
                height: 30,
                child: quantidadeNoCarrinho == 0
                    ? ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaria,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    setState(() {
                      int qtdAdicionar = 1;
                      if (meta != null) {
                        int qtdMeta = meta['quantidade'] ?? 1;
                        if (eVariavelPorPeso) {
                          qtdAdicionar = meta['ePeso'] ? qtdMeta : 1000;
                        } else {
                          qtdAdicionar = meta['ePeso'] ? 1 : qtdMeta;
                        }
                      } else if (eVariavelPorPeso) {
                        qtdAdicionar = 1000;
                      }
                      widget.carrinho[produtoId] = qtdAdicionar;
                    });
                  },
                  child: const Text('Adicionar', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                )
                    : Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaria),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.remove, size: 14, color: AppColors.primaria),
                        onPressed: () {
                          setState(() {
                            int decremento = eVariavelPorPeso ? 250 : 1;
                            if (quantidadeNoCarrinho > decremento) {
                              widget.carrinho[produtoId] = quantidadeNoCarrinho - decremento;
                            } else {
                              widget.carrinho.remove(produtoId);
                            }
                          });
                        },
                      ),
                      Text(
                        eVariavelPorPeso
                            ? '${(quantidadeNoCarrinho / 1000.0).toStringAsFixed(2).replaceAll('.', ',')}kg'
                            : '$quantidadeNoCarrinho',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaria),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.add, size: 14, color: AppColors.primaria),
                        onPressed: () {
                          setState(() {
                            int incremento = eVariavelPorPeso ? 250 : 1;
                            widget.carrinho[produtoId] = quantidadeNoCarrinho + incremento;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
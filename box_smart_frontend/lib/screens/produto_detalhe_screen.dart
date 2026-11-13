import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../widgets/produto_card.dart';

class ProdutoDetalheScreen extends StatefulWidget {
  final int clienteId;
  final String token;
  final Set<int> favoritosIds;
  final Map<String, dynamic> produto;
  final Map<int, int> carrinho;
  final List<dynamic> produtosListaGlobal;

  const ProdutoDetalheScreen({
    super.key,
    required this.clienteId,
    required this.token,
    required this.favoritosIds,
    required this.produto,
    required this.carrinho,
    required this.produtosListaGlobal,
  });

  @override
  State<ProdutoDetalheScreen> createState() => _ProdutoDetalheScreenState();
}

class _ProdutoDetalheScreenState extends State<ProdutoDetalheScreen> {
  // 1. O produto recebido via navegação (widget.produto) tem prioridade sobre a lista global
  Map<String, dynamic> get _produtoCompleto {
    final Map<String, dynamic> prodMap = {};

    if (widget.produtosListaGlobal.isNotEmpty) {
      final idBusca = widget.produto['id']?.toString() ?? widget.produto['codigo']?.toString();
      if (idBusca != null) {
        final completo = widget.produtosListaGlobal.firstWhere(
              (p) {
            if (p is! Map) return false;
            final idGlobal = p['id']?.toString() ?? p['codigo']?.toString();
            return idGlobal == idBusca;
          },
          orElse: () => null,
        );
        if (completo != null && completo is Map<String, dynamic>) {
          prodMap.addAll(completo);
        }
      }
    }

    // Sobrescreve com os dados do produto recebido diretamente na navegação (dados mais recentes)
    prodMap.addAll(Map<String, dynamic>.from(widget.produto));
    return prodMap;
  }

  int get _produtoId {
    final prod = _produtoCompleto;
    final dynamic rawId = prod['id'] ?? prod['codigo'];
    return int.tryParse(rawId.toString()) ?? (rawId is int ? rawId : widget.produto.hashCode);
  }

  // 2. Detecção de peso variável
  bool get _eVariavelPorPeso {
    final prod = _produtoCompleto;
    final String nome = (prod['nome'] ?? '').toString().toLowerCase();
    final String un = (prod['unidade'] ?? prod['unidade_medida'] ?? '').toString().trim().toLowerCase();

    final dynamic varPeso = prod['variavel_por_peso'] ?? prod['peso_variavel'] ?? prod['fracionado'] ?? prod['pesavel'];
    if (varPeso == true || varPeso == 1 || varPeso.toString().toLowerCase() == 'true') return true;

    if (['kg', 'quilo', 'quilos', 'g', 'gramas'].contains(un) || un.startsWith('kg')) return true;

    return nome.contains('patinho') ||
        nome.contains('alcatra') ||
        nome.contains('contra') ||
        nome.contains('moída') ||
        nome.contains('carne') ||
        nome.contains('frango') ||
        nome.contains('queijo') ||
        nome.contains('presunto') ||
        nome.contains('banana') ||
        nome.contains('kg');
  }

  int get _quantidadeNoCarrinho => widget.carrinho[_produtoId] ?? 0;

  void _alterarQuantidade(int novaQuantidade) {
    setState(() {
      if (novaQuantidade <= 0) {
        widget.carrinho.remove(_produtoId);
      } else {
        widget.carrinho[_produtoId] = novaQuantidade;
      }
    });
  }

  // 3. Modal de seleção customizada de peso
  void _abrirModalPeso() {
    final prod = _produtoCompleto;
    int gramasAtuais = _quantidadeNoCarrinho > 0 ? _quantidadeNoCarrinho : 250;
    double kgInicial = gramasAtuais / 1000.0;

    final TextEditingController pesoController = TextEditingController(
      text: kgInicial.toStringAsFixed(3).replaceAll('.', ','),
    );

    showDialog(
      context: context,
      builder: (modalContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.scale_rounded, color: AppColors.primaria),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Selecionar Peso: ${prod['nome'] ?? ''}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informe a quantidade em Quilogramas (kg):',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pesoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Peso (ex: 0,500 para 500g)',
                      border: OutlineInputBorder(),
                      suffixText: 'kg',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Sugestões rápidas:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _botaoSugestao('250g', 0.25, pesoController),
                      _botaoSugestao('500g', 0.50, pesoController),
                      _botaoSugestao('1 kg', 1.00, pesoController),
                      _botaoSugestao('1,5 kg', 1.50, pesoController),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(modalContext),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaria,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final double? pesoKg = double.tryParse(pesoController.text.replaceAll(',', '.'));
                if (pesoKg == null || pesoKg <= 0) return;

                final int gramas = (pesoKg * 1000).round();
                _alterarQuantidade(gramas);
                Navigator.pop(modalContext);
              },
              child: const Text('Confirmar Peso', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuemViuTambemViu() {
    final recomendacoes = widget.produtosListaGlobal.where((p) {
      if (p is! Map) return false;

      final idStr = p['id']?.toString() ?? p['codigo']?.toString();
      if (idStr == _produtoId.toString()) return false; // Não mostra o próprio produto

      // --- FILTRO DE IMAGEM E ESTOQUE APLICADO NAS RECOMENDAÇÕES ---
      final String imgUrl = p['imagem_url']?.toString().toLowerCase() ?? '';
      if (imgUrl.contains('seu-storage.com.br') || imgUrl.contains('seustorage')) {
        return false;
      }

      final dynamic rawEstoque = p['estoque'] ?? p['qtd_estoque'] ?? p['quantidade_estoque'];
      if (rawEstoque != null) {
        final double? estoqueNum = double.tryParse(rawEstoque.toString().replaceAll(',', '.'));
        if (estoqueNum != null && estoqueNum <= 0) {
          return false;
        }
      }

      return true;
    }).take(10).toList();

    if (recomendacoes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text(
            'Quem viu este item, também viu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recomendacoes.length,
            itemBuilder: (context, index) {
              final prodRelacionado = recomendacoes[index];

              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 12, bottom: 6),
                child: ProdutoCard(
                  produto: prodRelacionado,
                  carrinho: widget.carrinho,
                  favoritosIds: widget.favoritosIds,
                  produtosListaGlobal: widget.produtosListaGlobal,
                  onCarrinhoAlterado: () => setState(() {}),
                  onToggleFavorito: (id) {
                    setState(() {
                      if (widget.favoritosIds.contains(id)) {
                        widget.favoritosIds.remove(id);
                      } else {
                        widget.favoritosIds.add(id);
                      }
                    });
                  },
                  onTapDetalhes: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProdutoDetalheScreen(
                          clienteId: widget.clienteId,
                          token: widget.token,
                          favoritosIds: widget.favoritosIds,
                          produto: prodRelacionado,
                          carrinho: widget.carrinho,
                          produtosListaGlobal: widget.produtosListaGlobal,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _botaoSugestao(String texto, double pesoKg, TextEditingController controller) {
    return InkWell(
      onTap: () {
        controller.text = pesoKg.toStringAsFixed(3).replaceAll('.', ',');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          texto,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prod = _produtoCompleto;
    final bool pesavel = _eVariavelPorPeso;

    // 🎯 Captura inteligente de Preço Normal vs Preço Clube
    final double precoNormal = double.tryParse(prod['preco'].toString().replaceAll(',', '.')) ?? 0.0;
    final dynamic precoClubeRaw = prod['preco_clube'];
    final bool temPrecoClube = precoClubeRaw != null;
    final double precoClube = temPrecoClube
        ? (double.tryParse(precoClubeRaw.toString().replaceAll(',', '.')) ?? 0.0)
        : 0.0;

    final bool eFavorito = widget.favoritosIds.contains(_produtoId);

    return Scaffold(
      appBar: AppBar(
        title: Text(prod['nome'] ?? 'Detalhes do Produto', style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: Icon(
              eFavorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: eFavorito ? Colors.red : Colors.grey,
            ),
            onPressed: () async {
              setState(() {
                if (eFavorito) {
                  widget.favoritosIds.remove(_produtoId);
                } else {
                  widget.favoritosIds.add(_produtoId);
                }
              });

              try {
                await http.post(
                  Uri.parse('http://192.168.15.175:8000/clientes/${widget.clienteId}/favoritos/$_produtoId'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer ${widget.token}',
                  },
                );
              } catch (e) {
                debugPrint('Erro ao salvar favorito nos detalhes: $e');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGEM DO PRODUTO
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: prod['imagem_url'] != null && prod['imagem_url'].toString().startsWith('http')
                  ? Image.network(prod['imagem_url'], fit: BoxFit.contain)
                  : const Icon(Icons.shopping_bag, size: 100, color: Colors.grey),
            ),
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prod['nome'] ?? '',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),

                  // 🌟 EXIBIÇÃO INTELIGENTE DE PREÇO (NORMAL VS CLUBE) NOS DETALHES
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (temPrecoClube && precoClube > 0) ...[
                        Row(
                          children: [
                            Text(
                              'R\$ ${precoNormal.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PREÇO CLUBE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        children: [
                          Text(
                            'R\$ ${(temPrecoClube && precoClube > 0 ? precoClube : precoNormal).toStringAsFixed(2).replaceAll('.', ',')}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: temPrecoClube && precoClube > 0 ? const Color(0xFFD97706) : AppColors.primaria,
                            ),
                          ),
                          Text(
                            '/${pesavel ? 'kg' : (prod['unidade'] ?? 'un')}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (pesavel) ...[
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.scale_outlined, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Produto vendido por peso (incrementos de 250g), preço final pode variar',
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Text(
                    'Descrição',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    prod['descricao'] ?? prod['detalhes'] ?? 'Sem descrição disponível.',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // SEÇÃO "QUEM VIU ESTE ITEM, TAMBÉM VIU"
            _buildQuemViuTambemViu(),
          ],
        ),
      ),

      // BARRA INFERIOR DE COMPRA E AJUSTE DE QUANTIDADE / PESO
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -3)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // CONTROLE DE QUANTIDADE / PESO
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 20, color: AppColors.primaria),
                      onPressed: () {
                        if (pesavel) {
                          if (_quantidadeNoCarrinho > 250) {
                            _alterarQuantidade(_quantidadeNoCarrinho - 250);
                          } else {
                            _alterarQuantidade(0);
                          }
                        } else {
                          if (_quantidadeNoCarrinho > 1) {
                            _alterarQuantidade(_quantidadeNoCarrinho - 1);
                          } else {
                            _alterarQuantidade(0);
                          }
                        }
                      },
                    ),
                    GestureDetector(
                      onTap: pesavel ? _abrirModalPeso : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          _quantidadeNoCarrinho == 0
                              ? (pesavel ? '0,250kg' : '1')
                              : (pesavel
                              ? '${(_quantidadeNoCarrinho / 1000.0).toStringAsFixed(3).replaceAll('.', ',')}kg'
                              : '$_quantidadeNoCarrinho'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaria),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20, color: AppColors.primaria),
                      onPressed: () {
                        if (pesavel) {
                          _alterarQuantidade(_quantidadeNoCarrinho == 0 ? 250 : _quantidadeNoCarrinho + 250);
                        } else {
                          _alterarQuantidade(_quantidadeNoCarrinho + 1);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // BOTÃO DE ADICIONAR / CONFIRMAR NO CARRINHO
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaria,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (_quantidadeNoCarrinho == 0) {
                        _alterarQuantidade(pesavel ? 250 : 1);
                      }
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${prod['nome']} atualizado no carrinho!'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                    label: Text(
                      _quantidadeNoCarrinho > 0 ? 'No Carrinho' : 'Adicionar',
                      style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
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
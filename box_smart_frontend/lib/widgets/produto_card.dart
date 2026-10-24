import 'package:flutter/material.dart';
import '../main.dart'; // Ajuste conforme a localização de AppColors no seu projeto

class ProdutoCard extends StatefulWidget {
  final Map<String, dynamic> produto;
  final Map<int, int> carrinho;
  final Set<int> favoritosIds;
  final List<dynamic> produtosListaGlobal;
  final VoidCallback onCarrinhoAlterado;
  final Function(int) onToggleFavorito;
  final VoidCallback onTapDetalhes;

  const ProdutoCard({
    super.key,
    required this.produto,
    required this.carrinho,
    required this.favoritosIds,
    required this.produtosListaGlobal,
    required this.onCarrinhoAlterado,
    required this.onToggleFavorito,
    required this.onTapDetalhes,
  });

  @override
  State<ProdutoCard> createState() => _ProdutoCardState();
}

class _ProdutoCardState extends State<ProdutoCard> {
  // Mescla o item resumido da Home com os dados completos da lista global
  Map<String, dynamic> get _produtoCompleto {
    final Map<String, dynamic> prodMap = Map<String, dynamic>.from(
      widget.produto,
    );

    if (widget.produtosListaGlobal.isNotEmpty) {
      final idBusca =
          prodMap['id']?.toString() ?? prodMap['codigo']?.toString();
      if (idBusca != null) {
        final completo = widget.produtosListaGlobal.firstWhere((p) {
          if (p is! Map) return false;
          final idGlobal = p['id']?.toString() ?? p['codigo']?.toString();
          return idGlobal == idBusca;
        }, orElse: () => <String, dynamic>{}); // 👈 Corrigido para evitar TypeError

        if (completo.isNotEmpty && completo is Map<String, dynamic>) {
          prodMap.addAll(completo);
        }
      }
    }
    return prodMap;
  }

  int get _produtoId {
    final prod = _produtoCompleto;
    final dynamic rawId = prod['id'] ?? prod['codigo'];
    return int.tryParse(rawId.toString()) ??
        (rawId is int ? rawId : widget.produto.hashCode);
  }

  // Detecção inteligente e garantida de produto pesável
  bool get _eVariavelPorPeso {
    final prod = _produtoCompleto;
    final String nome = (prod['nome'] ?? '').toString().toLowerCase();
    final String un = (prod['unidade'] ?? prod['unidade_medida'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    // 1. Flags explícitas do backend/ERP
    final dynamic varPeso =
        prod['variavel_por_peso'] ??
            prod['peso_variavel'] ??
            prod['fracionado'] ??
            prod['pesavel'];
    if (varPeso == true ||
        varPeso == 1 ||
        varPeso.toString().toLowerCase() == 'true') {
      return true;
    }

    // 2. Unidade de medida
    if (['kg', 'quilo', 'quilos', 'g', 'gramas'].contains(un) ||
        un.startsWith('kg')) {
      return true;
    }

    // 3. Detecção por nome (Açougue, Hortifrúti, Frios)
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

  // Verifica se o produto está sem estoque no backend
  bool get _semEstoque {
    final prod = _produtoCompleto;
    final dynamic rawEstoque =
        prod['estoque'] ??
            prod['qtd_estoque'] ??
            prod['quantidade_estoque'] ??
            prod['saldo_estoque'];

    if (rawEstoque == null) {
      return false;
    }

    final double? estoqueNum = double.tryParse(
      rawEstoque.toString().replaceAll(',', '.'),
    );
    return estoqueNum != null && estoqueNum <= 0;
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
    widget.onCarrinhoAlterado();
  }

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.scale_rounded, color: AppColors.primaria),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Selecionar Peso: ${prod['nome'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
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
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaria,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final double? pesoKg = double.tryParse(
                  pesoController.text.replaceAll(',', '.'),
                );
                if (pesoKg == null || pesoKg <= 0) return;

                final int gramas = (pesoKg * 1000).round();
                _alterarQuantidade(gramas);
                Navigator.pop(modalContext);
              },
              child: const Text(
                'Confirmar Peso',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _botaoSugestao(
      String texto,
      double pesoKg,
      TextEditingController controller,
      ) {
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
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prod = _produtoCompleto;
    final bool pesavel = _eVariavelPorPeso;
    final bool semEstoque = _semEstoque;

    // 🌟 Leitura robusta das flags de destaque vindas do portal
    final dynamic rawMaisVendido = prod['mais_vendido'] ?? prod['is_mais_vendido'] ?? prod['maisVendido'];
    final bool eMaisVendido = rawMaisVendido == true || rawMaisVendido == 1 || rawMaisVendido.toString().toLowerCase() == 'true' || rawMaisVendido.toString() == '1';

    final dynamic rawDestaque = prod['destaque'] ?? prod['is_destaque'] ?? prod['destacado'];
    final bool eDestaque = rawDestaque == true || rawDestaque == 1 || rawDestaque.toString().toLowerCase() == 'true' || rawDestaque.toString() == '1';

    final double precoNormal =
        double.tryParse(prod['preco'].toString().replaceAll(',', '.')) ?? 0.0;

    final dynamic precoClubeRaw = prod['preco_clube'];
    final bool temPrecoClube = precoClubeRaw != null && (double.tryParse(precoClubeRaw.toString().replaceAll(',', '.')) ?? 0.0) > 0;
    final double precoClube = temPrecoClube
        ? (double.tryParse(precoClubeRaw.toString().replaceAll(',', '.')) ?? 0.0)
        : 0.0;

    // 🏷️ Cálculo do percentual de desconto do Clube
    final bool temDesconto = temPrecoClube && precoClube > 0 && precoClube < precoNormal;
    final int percentualDesconto = temDesconto
        ? (((precoNormal - precoClube) / precoNormal) * 100).round()
        : 0;

    final bool eFavorito = widget.favoritosIds.contains(_produtoId);

    return GestureDetector(
      onTap: widget.onTapDetalhes,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 125,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: prod['imagem_url'] != null &&
                      prod['imagem_url'].toString().startsWith('http')
                      ? Image.network(
                    prod['imagem_url'],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.shopping_bag,
                      size: 50,
                      color: Colors.grey,
                    ),
                  )
                      : const Icon(
                    Icons.shopping_bag,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),

                // Selo ESGOTADO no canto superior esquerdo
                if (semEstoque)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ESGOTADO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // 🏷️ Selo de Percentual de Desconto do Clube (Ex: -15%)
                if (temDesconto && !semEstoque)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-$percentualDesconto%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                // Selo MAIS VENDIDO / DESTAQUE na lateral direita
                if ((eMaisVendido || eDestaque) && !semEstoque)
                  Positioned(
                    top: 15,
                    right: 0,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade800,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'MAIS VENDIDO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: Icon(
                      eFavorito
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: eFavorito ? Colors.red : Colors.grey,
                    ),
                    onPressed: () => widget.onToggleFavorito(_produtoId),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        prod['nome'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // 🌟 EXIBIÇÃO INTELIGENTE DE PREÇO NORMAL VS PREÇO CLUBE / BOX PRIME
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (temPrecoClube && precoClube > 0) ...[
                          Row(
                            children: [
                              Text(
                                'R\$ ${precoNormal.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'BOX PRIME',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'R\$',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              (temPrecoClube && precoClube > 0 ? precoClube : precoNormal)
                                  .toStringAsFixed(2)
                                  .replaceAll('.', ','),
                              style: TextStyle(
                                fontSize: 16,
                                color: temPrecoClube && precoClube > 0
                                    ? Colors.green.shade800
                                    : Colors.black87,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '/${pesavel ? 'kg' : (prod['unidade'] ?? 'un')}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (pesavel)
                      const Row(
                        children: [
                          Icon(
                            Icons.scale_outlined,
                            size: 11,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              'Peso variável, preço final pode ser alterado',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),

                    // BOTÃO: INDISPONÍVEL VS ADICIONAR/CONTROLE
                    semEstoque
                        ? Container(
                      width: double.infinity,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.block_rounded,
                            size: 13,
                            color: Colors.red,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Indisponível',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    )
                        : _quantidadeNoCarrinho == 0
                        ? SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaria,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () {
                          if (pesavel) {
                            _abrirModalPeso();
                          } else {
                            _alterarQuantidade(1);
                          }
                        },
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Adicionar',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                        : Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaria),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
                            icon: const Icon(
                              Icons.remove,
                              size: 16,
                              color: AppColors.primaria,
                            ),
                            onPressed: () {
                              if (pesavel) {
                                if (_quantidadeNoCarrinho > 250) {
                                  _alterarQuantidade(_quantidadeNoCarrinho - 250);
                                } else {
                                  _alterarQuantidade(0);
                                }
                              } else {
                                _alterarQuantidade(_quantidadeNoCarrinho - 1);
                              }
                            },
                          ),
                          Expanded(
                            child: Center(
                              child: GestureDetector(
                                onTap: pesavel ? _abrirModalPeso : null,
                                child: Text(
                                  pesavel
                                      ? '${(_quantidadeNoCarrinho / 1000.0).toStringAsFixed(3).replaceAll('.', ',')}kg'
                                      : '$_quantidadeNoCarrinho',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaria,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
                            icon: const Icon(
                              Icons.add,
                              size: 16,
                              color: AppColors.primaria,
                            ),
                            onPressed: () {
                              if (pesavel) {
                                _alterarQuantidade(_quantidadeNoCarrinho + 250);
                              } else {
                                _alterarQuantidade(_quantidadeNoCarrinho + 1);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
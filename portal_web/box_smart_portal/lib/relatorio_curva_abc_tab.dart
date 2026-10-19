import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class RelatorioCurvaAbcTab extends StatefulWidget {
  final String baseUrl;
  final String token;

  const RelatorioCurvaAbcTab({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<RelatorioCurvaAbcTab> createState() => _RelatorioCurvaAbcTabState();
}

class _RelatorioCurvaAbcTabState extends State<RelatorioCurvaAbcTab> {
  List<dynamic> _produtos = [];
  Map<String, dynamic> _resumoClasses = {};
  double _receitaGlobal = 0.0;
  bool _isLoading = true;

  String _filtroClasse = 'TODAS'; // 'TODAS', 'A', 'B', 'C'
  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  final NumberFormat _formatoMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  @override
  void initState() {
    super.initState();
    _carregarRelatorioAbc();
  }

  Future<void> _carregarRelatorioAbc() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/admin/relatorios/curva-abc/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _receitaGlobal = double.tryParse(data['receita_global']?.toString() ?? '0') ?? 0.0;
          _resumoClasses = data['resumo_classes'] ?? {};
          _produtos = data['produtos'] ?? [];
          _isLoading = false;
        });
      } else {
        _mostrarErro('Erro ao carregar dados da Curva ABC.');
      }
    } catch (e) {
      _mostrarErro('Erro de conexão: $e');
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFB91C1C)),
    );
  }

  Color _corParaClasse(String classe) {
    switch (classe.toUpperCase()) {
      case 'A':
        return const Color(0xFF10B981); // Emerald Green
      case 'B':
        return const Color(0xFF0284C7); // Sky Blue
      case 'C':
        return const Color(0xFFD97706); // Amber / Orange
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _bgCorParaClasse(String classe) {
    switch (classe.toUpperCase()) {
      case 'A':
        return const Color(0xFFECFDF5);
      case 'B':
        return const Color(0xFFE0F2FE);
      case 'C':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final produtosFiltrados = _produtos.where((p) {
      final classeMatch = _filtroClasse == 'TODAS' || p['classe'] == _filtroClasse;
      final nomeMatch = _termoBusca.isEmpty ||
          (p['nome'] ?? '').toString().toLowerCase().contains(_termoBusca.toLowerCase());
      return classeMatch && nomeMatch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CABEÇALHO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Curva ABC de Produtos (Pareto 80/20)',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Classificação do portfólio por relevância financeira e giro de vendas.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155)),
                onPressed: _carregarRelatorioAbc,
                tooltip: 'Atualizar Relatório',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. CARDS KPIs
          _buildKpiGrid(),
          const SizedBox(height: 20),

          // 3. FERRAMENTAS E FILTROS DE CLASSE
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _buscaController,
                  decoration: InputDecoration(
                    hintText: 'Buscar produto por nome...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5)),
                  ),
                  onChanged: (valor) {
                    setState(() => _termoBusca = valor.trim());
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildChipFiltro('Todas as Classes', 'TODAS'),
                    const SizedBox(width: 8),
                    _buildChipFiltro('Classe A (Alto Impacto)', 'A'),
                    const SizedBox(width: 8),
                    _buildChipFiltro('Classe B (Médio Giro)', 'B'),
                    const SizedBox(width: 8),
                    _buildChipFiltro('Classe C (Baixo Giro)', 'C'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. TABELA RANQUEADA
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                  : produtosFiltrados.isEmpty
                  ? const Center(child: Text('Nenhum produto encontrado.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)))
                  : ListView.separated(
                itemCount: produtosFiltrados.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final p = produtosFiltrados[index];
                  final String nome = p['nome'] ?? 'Sem nome';
                  final String classe = p['classe'] ?? 'C';
                  final int qtdVendida = (p['qtd_vendida'] as num).toInt();
                  final double receita = double.tryParse(p['receita_total']?.toString() ?? '0') ?? 0.0;
                  final double percIndiv = double.tryParse(p['percentual_individual']?.toString() ?? '0') ?? 0.0;
                  final double percAcum = double.tryParse(p['percentual_acumulado']?.toString() ?? '0') ?? 0.0;

                  final corTexto = _corParaClasse(classe);
                  final corBg = _bgCorParaClasse(classe);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Posição no Ranking
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Center(
                                child: Text(
                                  '#${index + 1}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                nome,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                              ),
                            ),

                            // Badge de Classe
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: corBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: corTexto.withOpacity(0.4)),
                              ),
                              child: Text(
                                'Classe $classe',
                                style: TextStyle(fontWeight: FontWeight.bold, color: corTexto, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              _formatoMoeda.format(receita),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E3A8A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Barra de Progresso Acumulada
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (percAcum / 100).clamp(0.0, 1.0),
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: corTexto,
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Detalhes Operacionais
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$qtdVendida unidades sold',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            Text(
                              'Part. Indiv: ${percIndiv.toStringAsFixed(1)}% • Acumulado: ${percAcum.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
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

  Widget _buildChipFiltro(String label, String valor) {
    final bool ativo = _filtroClasse == valor;
    return ChoiceChip(
      label: Text(label),
      selected: ativo,
      selectedColor: const Color(0xFF1E3A8A),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: ativo ? Colors.white : const Color(0xFF475569),
        fontWeight: ativo ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
      showCheckmark: false,
      onSelected: (bool selected) {
        if (selected) setState(() => _filtroClasse = valor);
      },
    );
  }

  Widget _buildKpiGrid() {
    final classA = _resumoClasses['classe_a'] ?? {};
    final classB = _resumoClasses['classe_b'] ?? {};
    final classC = _resumoClasses['classe_c'] ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isPequeno = constraints.maxWidth < 900;
        final cards = [
          _buildKpiCard('Classe A (Essenciais)', '${classA['quantidade'] ?? 0} itens', '${_formatoMoeda.format(classA['receita'] ?? 0)} (${classA['percentual'] ?? 0}%)', Icons.star_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5)),
          _buildKpiCard('Classe B (Moderados)', '${classB['quantidade'] ?? 0} itens', '${_formatoMoeda.format(classB['receita'] ?? 0)} (${classB['percentual'] ?? 0}%)', Icons.trending_up_rounded, const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
          _buildKpiCard('Classe C (Baixo Giro)', '${classC['quantidade'] ?? 0} itens', '${_formatoMoeda.format(classC['receita'] ?? 0)} (${classC['percentual'] ?? 0}%)', Icons.archive_outlined, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
          _buildKpiCard('Faturamento Analisado', _formatoMoeda.format(_receitaGlobal), '${_produtos.length} produtos em movimento', Icons.analytics_rounded, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
        ];

        if (isPequeno) {
          return Column(
            children: [
              Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: cards[2]), const SizedBox(width: 12), Expanded(child: cards[3])]),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]), const SizedBox(width: 12),
            Expanded(child: cards[1]), const SizedBox(width: 12),
            Expanded(child: cards[2]), const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.4)),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        ],
      ),
    );
  }
}
class PontoSerie {
  final String dia;
  final double vendaDia;
  final double vendaAcumulada;
  final double projecaoPeriodoAnterior;

  PontoSerie({
    required this.dia,
    required this.vendaDia,
    required this.vendaAcumulada,
    required this.projecaoPeriodoAnterior,
  });

  factory PontoSerie.fromJson(Map<String, dynamic> json) {
    return PontoSerie(
      dia: json['dia'] ?? '',
      vendaDia: (json['venda_dia'] as num?)?.toDouble() ?? 0.0,
      vendaAcumulada: (json['venda_acumulada'] as num?)?.toDouble() ?? 0.0,
      projecaoPeriodoAnterior: (json['projecao_periodo_anterior'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class VendasAcumuladasResponse {
  final String periodo;
  final double metaFaturamento;
  final double pontoCorteAlerta;
  final double faturamentoTotalAcumulado;
  final List<PontoSerie> serieHistorica;

  VendasAcumuladasResponse({
    required this.periodo,
    required this.metaFaturamento,
    required this.pontoCorteAlerta,
    required this.faturamentoTotalAcumulado,
    required this.serieHistorica,
  });

  factory VendasAcumuladasResponse.fromJson(Map<String, dynamic> json) {
    return VendasAcumuladasResponse(
      periodo: json['periodo'] ?? '',
      metaFaturamento: (json['meta_faturamento'] as num?)?.toDouble() ?? 0.0,
      pontoCorteAlerta: (json['ponto_corte_alerta'] as num?)?.toDouble() ?? 0.0,
      faturamentoTotalAcumulado: (json['faturamento_total_acumulado'] as num?)?.toDouble() ?? 0.0,
      serieHistorica: (json['serie_historica'] as List<dynamic>?)
          ?.map((item) => PontoSerie.fromJson(item))
          .toList() ??
          [],
    );
  }
}
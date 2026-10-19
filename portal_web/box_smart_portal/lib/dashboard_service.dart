import 'dart:convert';
import 'package:http/http.dart' as http;
import 'vendas_acumuladas_model.dart';

class DashboardService {
  final String baseUrl = 'http://127.0.0.1:8000'; // Ajuste para a URL do seu servidor

  Future<VendasAcumuladasResponse> buscarVendasAcumuladas({
    DateTime? dataInicio,
    DateTime? dataFim,
    double metaFaturamento = 250000.0,
  }) async {
    final queryParams = <String, String>{
      'meta_faturamento': metaFaturamento.toString(),
    };

    if (dataInicio != null) {
      queryParams['data_inicio'] = dataInicio.toIso8601String().split('T')[0];
    }
    if (dataFim != null) {
      queryParams['data_fim'] = dataFim.toIso8601String().split('T')[0];
    }

    final uri = Uri.parse('$baseUrl/admin/relatorios/vendas-acumuladas/').replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonMap = json.decode(utf8.decode(response.bodyBytes));
      return VendasAcumuladasResponse.fromJson(jsonMap);
    } else {
      throw Exception('Falha ao carregar relatório de vendas acumuladas');
    }
  }
}
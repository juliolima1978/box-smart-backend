import 'dart:convert';
import 'package:http/http.dart' as http;

class FreteModel {
  final double valorFrete;
  final double taxaPadrao;
  final double valorMinimoFreteGratis;
  final bool freteGratisHoje;
  final String motivo;
  final double faltamParaFreteGratis;

  FreteModel({
    required this.valorFrete,
    required this.taxaPadrao,
    required this.valorMinimoFreteGratis,
    required this.freteGratisHoje,
    required this.motivo,
    required this.faltamParaFreteGratis,
  });

  factory FreteModel.fromJson(Map<String, dynamic> json) {
    return FreteModel(
      valorFrete: (json['valor_frete'] as num).toDouble(),
      taxaPadrao: (json['taxa_padrao'] as num).toDouble(),
      valorMinimoFreteGratis: (json['valor_minimo_frete_gratis'] as num).toDouble(),
      freteGratisHoje: json['frete_gratis_hoje'] ?? false,
      motivo: json['motivo'] ?? '',
      faltamParaFreteGratis: (json['faltam_para_frete_gratis'] as num).toDouble(),
    );
  }
}

class FreteService {
  // Substitua pela URL do seu servidor (ex: http://10.0.2.2:8000 para emulador Android)
  static const String baseUrl = 'http://10.0.2.2:8000';

  Future<FreteModel> calcularFrete(double subtotal) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/frete/calcular?subtotal=$subtotal'),
    );

    if (response.statusCode == 200) {
      return FreteModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Erro ao calcular frete no servidor.');
    }
  }
}
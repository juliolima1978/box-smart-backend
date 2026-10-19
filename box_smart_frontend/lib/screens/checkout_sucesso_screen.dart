import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 👈 Import necessário para formatar a data/fuso
import 'historico_pedidos_screen.dart';
import 'home_screen.dart';


class CheckoutSucessoScreen extends StatelessWidget {
  final String baseUrl;
  final int clienteId;
  final String clienteNome;
  final String token;
  final int pedidoId;

  const CheckoutSucessoScreen({
    super.key,
    required this.baseUrl,
    required this.clienteId,
    required this.clienteNome,
    required this.token,
    required this.pedidoId,
  });

  // Função auxiliar para corrigir o fuso horário e o padrão visual da data
  String formatarDataPedido(String dataIso) {
    try {
      DateTime dataUtc = DateTime.parse(dataIso);
      DateTime dataLocal = dataUtc.toLocal();

      // Formatação nativa em Dart sem precisar do pacote intl
      String dia = dataLocal.day.toString().padLeft(2, '0');
      String mes = dataLocal.month.toString().padLeft(2, '0');
      String ano = dataLocal.year.toString();
      String hora = dataLocal.hour.toString().padLeft(2, '0');
      String minuto = dataLocal.minute.toString().padLeft(2, '0');

      return '$dia/$mes/$ano às $hora:$minuto';
    } catch (e) {
      return dataIso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 80,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pedido Realizado com Sucesso!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'O seu pedido #${pedidoId} foi enviado para a nossa central e já está sendo processado.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MeusPedidosScreen(
                          baseUrl: baseUrl,
                          clienteId: clienteId,
                          token: token,
                        ),
                      ),
                          (route) => route.isFirst,
                    );
                  },
                  child: const Text(
                    'Acompanhar Meus Pedidos',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomeScreen(
                          //baseUrl: baseUrl, // 👈 Descomentado corretamente aqui
                          clienteNome: clienteNome,
                          clienteId: clienteId,
                          token: token,
                        ),
                      ),
                          (route) => false,
                    );
                  },
                  child: const Text(
                    'Voltar ao Início',
                    style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 16, fontWeight: FontWeight.bold),
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
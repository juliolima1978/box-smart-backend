// lib/widgets/footer.dart
import 'package:flutter/material.dart';
import '../main.dart'; // Para acessar AppColors

class FooterWidget extends StatelessWidget {
  const FooterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildFooter(context);
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      color: AppColors.primaria,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 900;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildColunaLogo(),
                    _buildColunaLinks('Institucional', ['Sobre Nós', 'Nossos Serviços', 'Carreira', 'Blog', 'Fale Conosco']),
                    _buildColunaLinks('Plataforma', ['Funcionalidades', 'Segurança', 'Integrações', 'Planos e Preços', 'Para Empresas']),
                    _buildColunaLinks('Suporte', ['Central de Ajuda', 'Termos de Uso', 'Política de Privacidade', 'Status das Operações', 'Área do Cliente']),
                    _buildColunaNewsletter(),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildColunaLogo(),
                    const SizedBox(height: 30),
                    _buildColunaLinks('Institucional', ['Sobre Nós', 'Nossos Serviços', 'Carreira', 'Blog', 'Fale Conosco']),
                    const SizedBox(height: 25),
                    _buildColunaLinks('Plataforma', ['Funcionalidades', 'Segurança', 'Integrações', 'Planos e Preços', 'Para Empresas']),
                    const SizedBox(height: 25),
                    _buildColunaLinks('Suporte', ['Central de Ajuda', 'Termos de Uso', 'Política de Privacidade', 'Status das Operações', 'Área do Cliente']),
                    const SizedBox(height: 30),
                    _buildColunaNewsletter(),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 40),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 700;
              if (isDesktop) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '© 2026 BEMG Tecnologia Ltda. Todos os direitos reservados.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    Row(
                      children: [
                        const Text(
                          'Métodos de pagamento (Visa, MasterCard, Elo, Pix)',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        const SizedBox(width: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Feito com ❤️ no Brasil',
                            style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '© 2026 Box Smart Tecnologia Ltda. Todos os direitos reservados.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Métodos de pagamento: Visa, MasterCard, Elo, Pix',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Feito com ❤️ no Brasil',
                        style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColunaLogo() {
    return SizedBox(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.store, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text(
                'Box Smart',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Soluções inteligentes para organização e gestão de espaços.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildSocialIcon(Icons.business),
              const SizedBox(width: 12),
              _buildSocialIcon(Icons.camera_alt),
              const SizedBox(width: 12),
              _buildSocialIcon(Icons.facebook),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  Widget _buildColunaLinks(String titulo, List<String> itens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        ...itens.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            item,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        )),
      ],
    );
  }

  Widget _buildColunaNewsletter() {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assine a Newsletter',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          const Text(
            'Receba novidades e dicas exclusivas diretamente no seu e-mail.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Seu melhor e-mail',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                onPressed: () {},
                child: const Text('Inscrever', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
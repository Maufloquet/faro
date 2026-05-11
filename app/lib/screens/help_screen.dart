import 'package:flutter/material.dart';

import 'about_screen.dart';

/// Tela de ajuda — explica o produto sem ser onboarding obrigatório.
///
/// Acessível via ícone "?" na app bar do mapa. Inspirada no padrão
/// {name}_help_screen.dart adotado em outros apps do autor.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Como o Faro funciona', style: TextStyle(fontFamily: 'Georgia')),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Sobre o Faro',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [
          _Hero(),
          SizedBox(height: 28),
          _FeatureCard(
            icon: Icons.map_outlined,
            title: 'Não somos um mapa de crimes',
            body:
                'Mostramos o que está acontecendo perto de você agora — não estatística histórica. A intenção é ajudar uma decisão pontual: passar por aqui, ou desviar?',
          ),
          _FeatureCard(
            icon: Icons.warning_amber_rounded,
            title: 'Nunca afirmamos segurança',
            body:
                'A única mensagem possível é "sem relatos recentes nesta área". O app não diz que algum lugar é seguro — só comunica probabilidade e ausência de relatos.',
          ),
          _FeatureCard(
            icon: Icons.layers_outlined,
            title: 'Várias fontes, pesos diferentes',
            body:
                'Hoje usamos dados em tempo real do Fogo Cruzado (RJ, PE, BA, PA). Ao longo da V2 entram relatos de usuários, scraping de portais locais e canais públicos do Telegram — cada fonte com peso próprio.',
          ),
          _FeatureCard(
            icon: Icons.lock_outline,
            title: 'Privacidade desde o dia 1',
            body:
                'Sua localização é usada para mostrar relatos próximos. Não armazenamos histórico individual de trajetos. Dados agregados por região, nunca por pessoa.',
          ),
          SizedBox(height: 16),
          _Privacy(),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O que está\nacontecendo perto\nde você agora?',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 28,
              height: 1.15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'O Faro lê fontes públicas em tempo real e mostra a movimentação do entorno. Ajuda a decidir uma rota, não a confirmar uma certeza.',
            style: TextStyle(fontSize: 14.5, height: 1.45, color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _FeatureCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DFD3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 22, color: const Color(0xFF7A5C2C)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    height: 1.25,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF3A3A3A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Privacy extends StatelessWidget {
  const _Privacy();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDCDCD2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Erros acontecem. Quando um relato se mostrar impreciso, ele pode ser contestado e expira automaticamente. O app não substitui sua atenção — só a complementa.',
        style: TextStyle(fontSize: 12.5, height: 1.55, color: Color(0xFF555555)),
      ),
    );
  }
}

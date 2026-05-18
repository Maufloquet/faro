import 'package:flutter/material.dart';

import '../core/design/tokens.dart';
import '../services/analytics_service.dart';
import 'about_screen.dart';

/// Tela de ajuda — explica o produto sem ser onboarding obrigatório.
///
/// Acessível via ícone "?" na app bar do mapa. Inspirada no padrão
/// {name}_help_screen.dart adotado em outros apps do autor.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('help');
  }

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
          SizedBox(height: 24),
          _AudienceHeader(),
          SizedBox(height: 12),
          _AudienceCard(
            icon: Icons.directions_bus_outlined,
            title: 'Se você anda de ônibus',
            body:
                'Antes de sair, abra o mapa e use o filtro 24h pra ver o que rolou hoje na região onde vai descer. Em Atividade por Área você vê quais linhas foram citadas em relatos recentes — não pra evitar, pra se preparar (escolher horário, descer um ponto antes ou depois).',
          ),
          _AudienceCard(
            icon: Icons.local_taxi_outlined,
            title: 'Se você é motorista de aplicativo',
            body:
                'Antes de aceitar corrida pra destino desconhecido, busque o bairro no mapa. Em 2 segundos você vê os relatos das últimas 24h. O Faro NÃO recomenda recusar corridas — discriminação territorial é ilegal e viola termos das plataformas. Damos contexto pra decisão, não veredito.',
          ),
          _AudienceCard(
            icon: Icons.delivery_dining_outlined,
            title: 'Se você é entregador',
            body:
                'Mesmo princípio do motorista: contexto antes da entrega. Em rotas noturnas em áreas pouco familiares, olhe o bairro antes de aceitar. A tela "Atividade por área" mostra onde concentraram relatos nas últimas semanas — útil pra escolher horários de menor exposição.',
          ),
          _AudienceCard(
            icon: Icons.place_outlined,
            title: 'Se você está visitando Salvador',
            body:
                'Vá na tela Sobre e salve seu hotel como "Local de referência". O Faro vai te avisar se houver relatos no entorno dele mesmo quando você estiver longe — útil pra decidir horário de volta ou se vai de Uber ou andando.',
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
            style: TextStyle(fontSize: 14.5, height: 1.45, color: FaroColors.textMuted),
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
        color: FaroColors.sand,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FaroColors.sandBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 22, color: FaroColors.editorialBrown),
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
                    color: FaroColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(fontSize: 13.5, height: 1.5, color: FaroColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceHeader extends StatelessWidget {
  const _AudienceHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Como usar pra cada perfil',
          style: TextStyle(
            fontFamily: FaroFonts.serifEditorial,
            fontSize: 20,
            color: FaroColors.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Caminhos práticos pensados pra quem usa o app por uma razão específica.',
          style: TextStyle(
            fontSize: 13,
            color: FaroColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _AudienceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _AudienceCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FaroRadii.card),
        border: Border.all(color: FaroColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: FaroColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: FaroFonts.serifEditorial,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FaroColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: FaroColors.textSecondary,
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
        border: Border.all(color: FaroColors.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Erros acontecem. Quando um relato se mostrar impreciso, ele pode ser contestado e expira automaticamente. O app não substitui sua atenção — só a complementa.',
        style: TextStyle(fontSize: 12.5, height: 1.55, color: FaroColors.textMuted),
      ),
    );
  }
}

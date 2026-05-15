import 'package:flutter/material.dart';

import '../services/analytics_service.dart';

/// Tela /sobre/ — transparência editorial pública.
///
/// Lista fontes de dados, princípios e contato. Acessível pela tela de
/// ajuda. Mantém o tom editorial: honesta sobre limitações.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('about');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre o Faro', style: TextStyle(fontFamily: 'Georgia')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: const [
          _Section(
            title: 'O que somos',
            body:
                'Um assistente de decisão urbana em tempo real. Mostramos o que está acontecendo perto de você combinando fontes públicas e (futuramente) relatos de usuários. Não somos um mapa de crimes. Não substituímos sua atenção.',
          ),
          _Section(
            title: 'O que não somos',
            body:
                'Não somos um produto de garantia. Nunca dizemos "está seguro". A única mensagem possível em uma região sem relatos é "sem relatos recentes" — silêncio nos dados não é silêncio nas ruas. Mantenha atenção sempre.',
          ),
          _Section(
            title: 'Fontes de dados',
            body:
                'Hoje: Fogo Cruzado (banco público de violência armada — RJ, PE, BA, PA). Próximas: relatos de usuários com validação coletiva, scraping de portais locais de notícia, monitoramento de canais públicos do Telegram. Cada fonte com peso diferente no cálculo de risco.',
          ),
          _Section(
            title: 'Como classificamos o risco',
            body:
                'Combinamos peso da fonte, idade do relato e densidade de confirmações. Reportes antigos perdem peso automaticamente. Múltiplas fontes independentes corroborando elevam o nível. Uma única fonte isolada nunca sustenta classificação alta.',
          ),
          _Section(
            title: 'Sobre viés algorítmico',
            body:
                'Periferias têm mais policiamento e mais cobertura de mídia — não necessariamente mais crime real. Mais boletins em uma região indicam mais visibilidade, não mais risco. Quando não temos dados suficientes em uma área, dizemos isso explicitamente, em vez de assumir que é seguro.',
          ),
          _Section(
            title: 'Privacidade',
            body:
                'Sua localização é usada apenas para mostrar relatos próximos. Não armazenamos seu histórico individual de trajetos. Dados agregados por região, nunca por pessoa. A política de privacidade completa está disponível em desenvolvimento.',
          ),
          _Section(
            title: 'Para quem anda de ônibus',
            body:
                'Você é passageiro frequente de ônibus? O Faro hoje ajuda você a avaliar a região onde vai descer antes de chegar. Use o filtro de 24h e a busca por bairro pra olhar antecipadamente. Funções específicas pra ponto de ônibus e trecho a pé estão na V2 do roadmap.',
          ),
          _Section(
            title: 'Contato',
            body:
                'Email: faro@example.com (placeholder — em produção será real). Toda contestação de relato é respondida em até 2h durante o beta.',
          ),
          SizedBox(height: 24),
          _Version(),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 17,
              height: 1.25,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xFF3A3A3A),
            ),
          ),
        ],
      ),
    );
  }
}

class _Version extends StatelessWidget {
  const _Version();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Faro · v0.1.0 (alpha)',
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF8A8A8A),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

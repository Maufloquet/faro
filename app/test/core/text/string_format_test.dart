import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/core/text/string_format.dart';

void main() {
  group('titleCasePtBr', () {
    test('retorna string vazia pra null ou vazio', () {
      expect(titleCasePtBr(null), '');
      expect(titleCasePtBr(''), '');
      expect(titleCasePtBr('   '), '');
    });

    test('capitaliza palavras em maiúscula', () {
      expect(titleCasePtBr('GOES CALMON'), 'Goes Calmon');
      expect(titleCasePtBr('BARRA'), 'Barra');
    });

    test('preserva acentos quando presentes', () {
      expect(titleCasePtBr('são cristóvão'), 'São Cristóvão');
      expect(titleCasePtBr('SÃO CRISTÓVÃO'), 'São Cristóvão');
    });

    test('mantém preposições/conjunções em minúsculo no meio', () {
      expect(titleCasePtBr('vila de são pedro'), 'Vila de São Pedro');
      expect(titleCasePtBr('serra do mar'), 'Serra do Mar');
      expect(titleCasePtBr('itapuã e pituba'), 'Itapuã e Pituba');
    });

    test('capitaliza preposição se for a primeira palavra', () {
      expect(titleCasePtBr('da serra'), 'Da Serra');
      expect(titleCasePtBr('e mais um'), 'E Mais Um');
    });

    test('normaliza múltiplos espaços', () {
      expect(titleCasePtBr('   foo    bar   '), 'Foo Bar');
    });
  });
}

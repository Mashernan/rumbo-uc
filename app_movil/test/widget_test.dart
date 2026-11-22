import 'package:flutter_test/flutter_test.dart';
import 'package:rumbo_uc/datos.dart';

void main() {
  test('El test de orientación tiene 12 preguntas y 4 áreas', () {
    expect(preguntas.length, 12);
    expect(areas.length, 4);
  });

  test('Un test con todas las respuestas máximas da 100 puntos', () {
    final respuestas = {for (var i = 0; i < 12; i++) '$i': '3'};
    expect(calcularResultado(respuestas).total, 100);
  });
}

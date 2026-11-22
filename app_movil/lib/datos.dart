// Preguntas, áreas y cálculo del resultado del test de orientación (HU05).
// Es la misma lógica que usa la versión web del PMV.

const List<String> enunciados = [
  '¿Cuántas horas a la semana estudias fuera de clase?',
  '¿Tienes un horario fijo para estudiar?',
  '¿Dónde estudias con mayor frecuencia?',
  'Cuando no entiendes un tema, ¿qué haces primero?',
  '¿Cómo preparas un examen?',
  '¿Cómo te organizas con tus tareas?',
  '¿Cuántas horas trabajas a la semana además de estudiar?',
  '¿Te sientes seguro de haber elegido tu carrera?',
  '¿Conoces los servicios de tutoría de tu universidad?',
  '¿Cuánto tiempo pasas en redes sociales mientras estudias?',
  '¿Cuánto descansas antes de un día de clases?',
  '¿Con quién estudias normalmente?',
];

const List<List<String>> opciones = [
  ['Menos de 3', 'De 3 a 6', 'De 7 a 10', 'Más de 10'],
  ['Nunca', 'A veces', 'Casi siempre', 'Siempre'],
  ['En casa, con distracciones', 'En el transporte o el trabajo', 'En casa, en un lugar tranquilo', 'En la biblioteca'],
  ['Lo dejo para después', 'Busco videos o internet', 'Pregunto a un compañero', 'Consulto al docente'],
  ['La noche anterior', 'Dos o tres días antes', 'Repaso cada semana', 'Con resúmenes y ejercicios'],
  ['No uso nada', 'De memoria', 'Agenda o celular', 'Planificador semanal'],
  ['Más de 20 h', 'De 10 a 20 h', 'Menos de 10 h', 'No trabajo'],
  ['Nada seguro', 'Poco seguro', 'Bastante seguro', 'Muy seguro'],
  ['No los conozco', 'Los conozco, no los uso', 'Los usé una vez', 'Los uso con frecuencia'],
  ['Casi todo el tiempo', 'Bastante', 'Poco', 'Nada'],
  ['Menos de 5 h', 'De 5 a 6 h', 'De 7 a 8 h', 'Más de 8 h'],
  ['Siempre solo y me cuesta', 'Solo, sin problema', 'A veces en grupo', 'En grupo con frecuencia'],
];

List<int> get preguntas => List<int>.generate(enunciados.length, (i) => i);

class Area {
  final String nombre;
  final List<int> preguntas;
  final String consejo;
  const Area(this.nombre, this.preguntas, this.consejo);
}

const List<Area> areas = [
  Area('Organización del tiempo', [0, 1, 5],
      'Arma un horario semanal con bloques de 50 minutos y 10 de descanso, a la misma hora cada día.'),
  Area('Técnicas de estudio', [3, 4],
      'Repasa cada semana con un resumen corto por curso y practica con ejercicios antes de los exámenes.'),
  Area('Entorno y bienestar', [2, 6, 9, 10],
      'Busca un lugar tranquilo, silencia el celular mientras estudias y duerme al menos 7 horas.'),
  Area('Vocación y apoyo', [7, 8, 11],
      'Conversa con tu tutora sobre tu carrera y aprovecha las tutorías y los grupos de estudio.'),
];

class PuntajeArea {
  final Area area;
  final int puntaje;
  const PuntajeArea(this.area, this.puntaje);
}

class Resultado {
  final String perfil;
  final int total;
  final List<PuntajeArea> areas;
  const Resultado(this.perfil, this.total, this.areas);

  String get texto => '$perfil ($total/100)';

  List<PuntajeArea> get masDebiles {
    final copia = List<PuntajeArea>.from(areas);
    copia.sort((a, b) => a.puntaje.compareTo(b.puntaje));
    return copia.take(2).toList();
  }
}

Resultado calcularResultado(Map<String, String> respuestas) {
  final lista = <PuntajeArea>[];
  for (final area in areas) {
    var suma = 0;
    for (final p in area.preguntas) {
      suma += int.tryParse(respuestas['$p'] ?? '') ?? 0;
    }
    lista.add(PuntajeArea(area, (suma / (area.preguntas.length * 3) * 100).round()));
  }
  var total = 0;
  for (final pa in lista) {
    total += pa.puntaje;
  }
  total = (total / lista.length).round();
  final perfil = total >= 70
      ? 'Estudiante organizado'
      : total >= 45
          ? 'Estudiante en construcción'
          : 'Estudiante por organizar';
  return Resultado(perfil, total, lista);
}

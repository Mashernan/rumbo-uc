// RUMBO_UC · App del estudiante (Flutter) · PMV Release 1
// HU15 ingreso y consentimiento · HU03 alerta temprana · HU05 test de orientación
// HU17 privacidad · HU18 accesibilidad (texto grande y alto contraste)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'config.dart';
import 'datos.dart';

const Color colorMarca = Color(0xFF0B5563);
const Color colorAlto = Color(0xFFB3261E);
const Color colorMedio = Color(0xFF9A5B00);
const Color colorBajo = Color(0xFF1E7A3A);

class Ajustes extends ChangeNotifier {
  bool textoGrande = false;
  bool altoContraste = false;

  void cambiarTexto(bool valor) {
    textoGrande = valor;
    notifyListeners();
  }

  void cambiarContraste(bool valor) {
    altoContraste = valor;
    notifyListeners();
  }
}

final Ajustes ajustes = Ajustes();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const RumboApp());
}

ThemeData construirTema(bool altoContraste) {
  ColorScheme esquema = ColorScheme.fromSeed(seedColor: altoContraste ? const Color(0xFF003C46) : colorMarca);
  if (altoContraste) {
    esquema = esquema.copyWith(
      primary: const Color(0xFF003C46),
      onSurface: Colors.black,
      onSurfaceVariant: Colors.black,
      outline: Colors.black,
      surface: Colors.white,
    );
  }
  return ThemeData(
    colorScheme: esquema,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: altoContraste ? const Color(0xFF003C46) : colorMarca,
      foregroundColor: Colors.white,
    ),
  );
}

class RumboApp extends StatelessWidget {
  const RumboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ajustes,
      builder: (context, _) {
        return MaterialApp(
          title: 'RUMBO_UC',
          debugShowCheckedModeBanner: false,
          theme: construirTema(ajustes.altoContraste),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(ajustes.textoGrande ? 1.25 : 1.0)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const Raiz(),
        );
      },
    );
  }
}

/// Muestra el ingreso o la app según haya sesión iniciada.
class Raiz extends StatelessWidget {
  const Raiz({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (Api.haySesion) {
          return const PantallaPrincipal();
        }
        return const PantallaIngreso();
      },
    );
  }
}

// =============================================================== utilidades de interfaz
String fechaTexto(dynamic valor) {
  if (valor == null) return '—';
  final d = DateTime.tryParse(valor.toString());
  if (d == null) return valor.toString();
  final l = d.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(l.day)}/${dos(l.month)}/${l.year} ${dos(l.hour)}:${dos(l.minute)}';
}

String numeroTexto(dynamic valor) {
  if (valor is num) {
    return valor == valor.roundToDouble() ? valor.round().toString() : valor.toStringAsFixed(1);
  }
  return '$valor';
}

class ChipNivel extends StatelessWidget {
  final String? nivel;
  const ChipNivel(this.nivel, {super.key});

  @override
  Widget build(BuildContext context) {
    final n = nivel ?? 'bajo';
    final color = n == 'alto' ? colorAlto : (n == 'medio' ? colorMedio : colorBajo);
    final texto = n == 'alto' ? 'Riesgo alto' : (n == 'medio' ? 'Riesgo medio' : 'Riesgo bajo');
    return Semantics(
      label: texto,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ),
    );
  }
}

class Aviso extends StatelessWidget {
  final String texto;
  final Color color;
  final IconData icono;
  const Aviso(this.texto, {super.key, this.color = colorMedio, this.icono = Icons.info_outline});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icono, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(texto)),
      ]),
    );
  }
}

void mostrarMensaje(BuildContext context, String texto) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
}

// =============================================================== IU-01 Ingreso (HU15)
class PantallaIngreso extends StatefulWidget {
  const PantallaIngreso({super.key});

  @override
  State<PantallaIngreso> createState() => _PantallaIngresoState();
}

class _PantallaIngresoState extends State<PantallaIngreso> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await Api.ingresar(_correo.text.trim(), _clave.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeError(e);
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formulario,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.explore, size: 72, color: colorMarca, semanticLabel: 'Logotipo de RUMBO_UC'),
                const SizedBox(height: 12),
                Text('RUMBO_UC', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Tu rumbo en la universidad: alertas a tiempo, tutoría y apoyo para tus primeros ciclos.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Correo institucional', border: OutlineInputBorder()),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Escribe tu correo.';
                    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(t)) return 'El correo no tiene un formato válido.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _clave,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                  validator: (v) => (v ?? '').isEmpty ? 'Escribe tu contraseña.' : null,
                  onFieldSubmitted: (_) => _ingresar(),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: const TextStyle(color: colorAlto, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _cargando ? null : _ingresar,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(_cargando ? 'Ingresando…' : 'Ingresar'),
                ),
                const SizedBox(height: 12),
                const Text('En la versión final, el ingreso se hará con el inicio de sesión institucional (SSO).',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================== Contenedor principal
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  Map<String, dynamic>? _perfil;
  Map<String, dynamic>? _resumen;
  String? _error;
  bool _cargando = true;
  int _pestana = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      _perfil ??= await Api.perfil();
      if (_perfil?['rol'] == 'estudiante') {
        _resumen = await Api.resumen();
      }
    } catch (e) {
      _error = mensajeError(e);
    }
    if (mounted) setState(() => _cargando = false);
  }

  void _irA(int pestana) => setState(() => _pestana = pestana);

  Widget _mensajeConSalida(String titulo, String texto) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Aviso(texto),
          if (_error != null) OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => Api.salir(), child: const Text('Cerrar sesión')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando && _resumen == null && _error == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) return _mensajeConSalida('Algo salió mal', _error!);
    if (_perfil?['rol'] != 'estudiante') {
      return _mensajeConSalida('Cuenta no válida',
          'Esta app es para estudiantes. Tu cuenta tiene el rol «${_perfil?['rol']}»: usa la plataforma web de RUMBO_UC.');
    }
    final resumen = _resumen ?? <String, dynamic>{};
    if (resumen['estudiante'] == null) {
      return _mensajeConSalida('Sin datos',
          'Tu cuenta aún no está vinculada a un registro de estudiante. Contacta a Coordinación de Bienestar.');
    }
    final consentimiento = Map<String, dynamic>.from((resumen['consentimiento'] as Map?) ?? {});
    final activo = consentimiento['activo'] == true;
    final revocado = consentimiento['revocado'] == true;
    if (!activo && !revocado) {
      return PantallaConsentimiento(
        alAceptar: () async {
          await Api.aceptarConsentimiento();
          await _cargar();
        },
      );
    }

    final estudiante = Map<String, dynamic>.from(resumen['estudiante'] as Map);
    final nombre = (estudiante['nombres'] ?? '').toString().split(' ').first;
    final titulos = ['Hola, $nombre', 'Test de orientación', 'Tutoría', 'Comunidad', 'Mi perfil'];
    final paginas = <Widget>[
      PestanaInicio(resumen: resumen, alRecargar: _cargar, irA: _irA),
      PestanaTest(key: ValueKey('test-${resumen['test']?['actualizado']}'), resumen: resumen, alRecargar: _cargar),
      const PestanaRelease2(
        titulo: 'Agenda de tutorías',
        historias: 'HU08',
        texto: 'Pronto podrás elegir un horario libre de tu tutora y recibir recordatorios. Mientras tanto, tu tutora te contactará cuando recibas una alerta.',
        ancla: 'app-agenda',
      ),
      const PestanaRelease2(
        titulo: 'Mentoría y comunidad',
        historias: 'HU09, HU11, HU12 y HU13',
        texto: 'Conectarás con un mentor de ciclos avanzados, compartirás material por curso y formarás grupos de estudio.',
        ancla: 'app-mentor',
      ),
      PestanaPerfil(resumen: resumen, alRecargar: _cargar),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titulos[_pestana])),
      body: SafeArea(child: paginas[_pestana]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: _irA,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Test'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Tutoría'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Comunidad'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

// =============================================================== IU-02 Consentimiento (HU15)
class PantallaConsentimiento extends StatefulWidget {
  final Future<void> Function() alAceptar;
  const PantallaConsentimiento({super.key, required this.alAceptar});

  @override
  State<PantallaConsentimiento> createState() => _PantallaConsentimientoState();
}

class _PantallaConsentimientoState extends State<PantallaConsentimiento> {
  bool _acepta = false;
  bool _guardando = false;

  Future<void> _aceptar() async {
    setState(() => _guardando = true);
    try {
      await widget.alAceptar();
    } catch (e) {
      if (mounted) {
        mostrarMensaje(context, mensajeError(e));
        setState(() => _guardando = false);
      }
    }
  }

  Widget _seccion(String titulo, String texto) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(texto),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uso de tus datos')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Antes de empezar, queremos contarte qué datos usamos y para qué.'),
          const SizedBox(height: 10),
          _seccion('Qué usamos',
              '• Tus notas y tu asistencia, para detectar a tiempo si necesitas apoyo.\n• Tus respuestas del test de orientación, solo si decides compartirlas.'),
          _seccion('Qué no usamos', 'Origen, salud ni nivel socioeconómico.'),
          _seccion('Tus derechos', 'Puedes revocar este consentimiento cuando quieras desde tu perfil (Ley N.° 29733).'),
          CheckboxListTile(
            value: _acepta,
            onChanged: (v) => setState(() => _acepta = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('He leído y acepto el uso de mis datos académicos para recibir alertas y apoyo.'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: (_acepta && !_guardando) ? _aceptar : null,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(_guardando ? 'Guardando…' : 'Aceptar y continuar'),
          ),
          TextButton(onPressed: () => Api.salir(), child: const Text('Salir')),
          const Text('Versión del consentimiento: 1.0', style: TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}

// =============================================================== IU-03 Inicio (HU03)
class PestanaInicio extends StatelessWidget {
  final Map<String, dynamic> resumen;
  final Future<void> Function() alRecargar;
  final void Function(int) irA;
  const PestanaInicio({super.key, required this.resumen, required this.alRecargar, required this.irA});

  @override
  Widget build(BuildContext context) {
    final consentimiento = Map<String, dynamic>.from((resumen['consentimiento'] as Map?) ?? {});
    final riesgo = resumen['riesgo'] == null ? null : Map<String, dynamic>.from(resumen['riesgo'] as Map);
    final alertas = (resumen['alertas'] as List?) ?? [];
    final test = resumen['test'] == null ? null : Map<String, dynamic>.from(resumen['test'] as Map);
    final respondidas = test == null ? 0 : ((test['respuestas'] as Map?)?.length ?? 0);
    final completado = test?['completado'] == true;
    final hayAlerta = riesgo != null && riesgo['nivel'] != 'bajo' && alertas.isNotEmpty;

    return RefreshIndicator(
      onRefresh: alRecargar,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (consentimiento['revocado'] == true)
          const Aviso('Revocaste el consentimiento: las alertas y el seguimiento están desactivados. Puedes volver a aceptarlo desde tu perfil.'),
        if (hayAlerta)
          Card(
            shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFC2410C), width: 2), borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final primera = Map<String, dynamic>.from(alertas.first as Map);
                if (primera['leida'] != true && primera['id'] is int) {
                  Api.marcarLeida(primera['id'] as int).catchError((_) {});
                }
                final destino = await Navigator.of(context).push<int>(
                  MaterialPageRoute(builder: (_) => PantallaAlerta(resumen: resumen)),
                );
                if (destino != null) irA(destino);
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        (Map<String, dynamic>.from(alertas.first as Map))['leida'] == true ? 'Tu recomendación' : 'Tienes una alerta nueva',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    ChipNivel(riesgo?['nivel']?.toString()),
                  ]),
                  const SizedBox(height: 8),
                  const Text('Detectamos algunas señales en tus cursos. Aún estás a tiempo: te ayudamos a retomar el ritmo.'),
                  const SizedBox(height: 6),
                  const Text('Toca para ver qué puedes hacer', style: TextStyle(decoration: TextDecoration.underline)),
                  const SizedBox(height: 4),
                  Text(fechaTexto((alertas.first as Map)['fecha']), style: const TextStyle(fontSize: 12)),
                ]),
              ),
            ),
          )
        else if (consentimiento['revocado'] != true)
          const Card(
            child: ListTile(
              leading: Icon(Icons.check_circle, color: colorBajo),
              title: Text('¡Vas bien!'),
              subtitle: Text('No tienes alertas. Sigue así.'),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Test de orientación'),
            subtitle: Text(completado ? 'Completado · toca para ver tu resultado' : 'Avance: $respondidas de ${enunciados.length} preguntas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: consentimiento['activo'] == true ? () => irA(1) : null,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Tu tutora'),
            subtitle: Text('${resumen['tutor'] ?? 'Por asignar'}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => irA(2),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Desliza hacia abajo para actualizar.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}

// =============================================================== IU-04 Alerta y recomendaciones (HU03)
class PantallaAlerta extends StatelessWidget {
  final Map<String, dynamic> resumen;
  const PantallaAlerta({super.key, required this.resumen});

  @override
  Widget build(BuildContext context) {
    final riesgo = Map<String, dynamic>.from(resumen['riesgo'] as Map);
    final f = Map<String, dynamic>.from((riesgo['factores'] as Map?) ?? {});
    Map<String, dynamic> factor(String k) => Map<String, dynamic>.from((f[k] as Map?) ?? {});
    final asistencia = factor('asistencia');
    final promedio = factor('promedio');
    final desaprobadas = factor('desaprobadas');
    final inactividad = factor('inactividad');

    final senales = <String>[
      if (asistencia['fuera'] == true)
        'Tu asistencia promedio es ${numeroTexto(asistencia['valor'])} % (lo recomendado es ${numeroTexto(asistencia['umbral'])} % o más).',
      if (promedio['fuera'] == true) 'Tu promedio parcial (${numeroTexto(promedio['valor'])}) puede mejorar.',
      if (desaprobadas['fuera'] == true) 'Tienes ${numeroTexto(desaprobadas['valor'])} evaluaciones por reforzar.',
      if (inactividad['fuera'] == true) 'No ingresas al aula virtual hace ${numeroTexto(inactividad['valor'])} días.',
    ];
    final tutor = '${resumen['tutor'] ?? 'tu tutora'}';
    final curso = '${resumen['curso_critico'] ?? 'tus cursos'}';

    Widget recomendacion(String titulo, String texto, int? pestana) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(texto),
            if (pestana != null) ...[
              const SizedBox(height: 8),
              FilledButton(onPressed: () => Navigator.of(context).pop(pestana), child: const Text('Ir ahora')),
            ],
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tu alerta')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Aviso('Vamos a tiempo. Detectamos algunas señales en tus cursos. Muchos estudiantes pasaron por esto y lo superaron con un poco de apoyo.',
              icono: Icons.wb_sunny_outlined),
          Row(children: [
            const Expanded(child: Text('Lo que notamos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            ChipNivel(riesgo['nivel']?.toString()),
          ]),
          const SizedBox(height: 6),
          for (final s in senales)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  '),
                Expanded(child: Text(s)),
              ]),
            ),
          const SizedBox(height: 12),
          const Text('Lo que puedes hacer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 6),
          if (asistencia['fuera'] == true) recomendacion('Conversa con tu tutora', 'Agenda una tutoría con $tutor para armar un plan.', 2),
          if (promedio['fuera'] == true || desaprobadas['fuera'] == true)
            recomendacion('Asiste a una asesoría', 'Refuerza $curso en las asesorías académicas.', 2),
          if (inactividad['fuera'] == true) recomendacion('Vuelve al aula virtual', 'Revisa las clases y tareas pendientes de esta semana.', null),
          recomendacion('Conoce tu forma de estudiar', 'El test de orientación te da consejos personalizados.', 1),
          const SizedBox(height: 6),
          Text('Calculado el ${fechaTexto(riesgo['fecha'])}. Tu tutora también fue informada para apoyarte.', style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}

// =============================================================== IU-05 / IU-06 Test y resultado (HU05)
class PestanaTest extends StatefulWidget {
  final Map<String, dynamic> resumen;
  final Future<void> Function() alRecargar;
  const PestanaTest({super.key, required this.resumen, required this.alRecargar});

  @override
  State<PestanaTest> createState() => _PestanaTestState();
}

class _PestanaTestState extends State<PestanaTest> {
  final Map<String, String> _respuestas = {};
  int _avance = 0;
  bool _completado = false;
  bool _compartir = false;
  bool _rehaciendo = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.resumen['test'];
    if (t is Map) {
      final r = t['respuestas'];
      if (r is Map) {
        r.forEach((k, v) => _respuestas['$k'] = '$v');
      }
      _completado = t['completado'] == true;
      _compartir = t['compartir'] == true;
      final a = t['avance'];
      _avance = _completado ? 0 : (a is int ? a : 0);
      if (_avance >= enunciados.length) _avance = enunciados.length - 1;
    }
  }

  bool get _consentimientoActivo {
    final c = widget.resumen['consentimiento'];
    return c is Map && c['activo'] == true;
  }

  Future<void> _guardar({required bool completado}) async {
    final res = completado ? calcularResultado(_respuestas).texto : null;
    await Api.guardarTest(
      respuestas: Map<String, String>.from(_respuestas),
      avance: _avance,
      completado: completado,
      resultado: res,
      compartir: _compartir,
    );
  }

  Future<void> _siguiente() async {
    if (_respuestas['$_avance'] == null) {
      setState(() => _error = 'Elige una respuesta para continuar.');
      return;
    }
    if (_avance == enunciados.length - 1) {
      setState(() => _guardando = true);
      try {
        await _guardar(completado: true);
        _completado = true;
        _rehaciendo = false;
        await widget.alRecargar();
      } catch (e) {
        if (mounted) mostrarMensaje(context, mensajeError(e));
      }
      if (mounted) setState(() => _guardando = false);
    } else {
      setState(() {
        _avance++;
        _error = null;
      });
      _guardar(completado: false).catchError((_) {});
    }
  }

  Future<void> _guardarYSalir() async {
    try {
      await _guardar(completado: false);
      if (mounted) mostrarMensaje(context, 'Avance guardado. Puedes continuar cuando quieras.');
      await widget.alRecargar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeError(e));
    }
  }

  Future<void> _cambiarCompartir(bool valor) async {
    setState(() => _compartir = valor);
    try {
      await _guardar(completado: true);
      if (mounted) mostrarMensaje(context, valor ? 'Tu tutora podrá ver tu resultado.' : 'Tu resultado ya no se comparte.');
    } catch (e) {
      if (mounted) {
        setState(() => _compartir = !valor);
        mostrarMensaje(context, mensajeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_consentimientoActivo) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Aviso('El test está desactivado porque revocaste el consentimiento. Puedes volver a aceptarlo desde tu perfil.'),
      );
    }
    if (_completado && !_rehaciendo) return _resultado();
    return _pregunta();
  }

  Widget _pregunta() {
    final i = _avance;
    final total = enunciados.length;
    final respondidas = _respuestas.length > total ? total : _respuestas.length;
    final progreso = respondidas / total;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Text('Pregunta ${i + 1} de $total'),
        const Spacer(),
        Text('${(progreso * 100).round()} %'),
      ]),
      const SizedBox(height: 6),
      Semantics(label: 'Avance del test: ${(progreso * 100).round()} por ciento', child: LinearProgressIndicator(value: progreso, minHeight: 8)),
      const SizedBox(height: 16),
      Text(enunciados[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 8),
      for (var k = 0; k < opciones[i].length; k++) _opcion(i, k),
      if (_error != null) Text(_error!, style: const TextStyle(color: colorAlto, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(children: [
        OutlinedButton(onPressed: i == 0 ? null : () => setState(() => _avance--), child: const Text('Anterior')),
        const Spacer(),
        FilledButton(
          onPressed: _guardando ? null : _siguiente,
          child: Text(i == total - 1 ? 'Ver resultado' : 'Siguiente'),
        ),
      ]),
      const SizedBox(height: 8),
      TextButton(onPressed: _guardarYSalir, child: const Text('Guardar y continuar después')),
      const Text('Tus respuestas son confidenciales. Solo tu tutora las verá si tú lo autorizas.', style: TextStyle(fontSize: 12)),
    ]);
  }

  Widget _opcion(int pregunta, int k) {
    final elegida = _respuestas['$pregunta'] == '$k';
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: elegida,
      button: true,
      child: Card(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: elegida ? color : Colors.grey, width: elegida ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _respuestas['$pregunta'] = '$k';
              _error = null;
            });
            _guardar(completado: false).catchError((_) {});
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(children: [
              Icon(elegida ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: elegida ? color : Colors.grey),
              const SizedBox(width: 10),
              Expanded(child: Text(opciones[pregunta][k])),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _resultado() {
    final r = calcularResultado(_respuestas);
    Color colorPuntaje(int p) => p >= 70 ? colorBajo : (p >= 45 ? colorMedio : colorAlto);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tu perfil de estudio', style: TextStyle(fontSize: 12)),
            Text(r.perfil, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Puntaje general: ${r.total} / 100'),
          ]),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tus áreas', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final a in r.areas) ...[
              const SizedBox(height: 10),
              Row(children: [Expanded(child: Text(a.area.nombre)), Text('${a.puntaje}', style: const TextStyle(fontWeight: FontWeight.bold))]),
              const SizedBox(height: 4),
              Semantics(
                label: '${a.area.nombre}: ${a.puntaje} de 100',
                child: LinearProgressIndicator(value: a.puntaje / 100, minHeight: 8, color: colorPuntaje(a.puntaje)),
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 6),
      const Text('Recomendaciones para ti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      for (final a in r.masDebiles)
        Card(child: ListTile(title: Text(a.area.nombre), subtitle: Text(a.area.consejo))),
      SwitchListTile(
        value: _compartir,
        onChanged: _cambiarCompartir,
        title: const Text('Autorizo compartir mi resultado con mi tutora'),
        subtitle: const Text('Si no lo autorizas, tu tutora solo verá que completaste el test.'),
      ),
      OutlinedButton(
        onPressed: () => setState(() {
          _rehaciendo = true;
          _respuestas.clear();
          _avance = 0;
        }),
        child: const Text('Volver a hacer el test'),
      ),
    ]);
  }
}

// =============================================================== Release 2 (prototipo)
class PestanaRelease2 extends StatelessWidget {
  final String titulo;
  final String historias;
  final String texto;
  final String ancla;
  const PestanaRelease2({super.key, required this.titulo, required this.historias, required this.texto, required this.ancla});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Chip(label: Text('Release 2 · Sprints 4 a 6')),
      const SizedBox(height: 8),
      Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      const SizedBox(height: 8),
      Text(texto),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Esta función no forma parte del PMV. Puedes ver cómo funcionará en el prototipo navegable.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('$urlPrototipo#$ancla'), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ver prototipo'),
            ),
          ]),
        ),
      ),
      Text('Historias: $historias', style: const TextStyle(fontSize: 12)),
    ]);
  }
}

// =============================================================== IU-15 Perfil, privacidad y accesibilidad (HU15, HU17, HU18)
class PestanaPerfil extends StatelessWidget {
  final Map<String, dynamic> resumen;
  final Future<void> Function() alRecargar;
  const PestanaPerfil({super.key, required this.resumen, required this.alRecargar});

  Future<void> _revocar(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revocar consentimiento'),
        content: const Text(
            'Si revocas el consentimiento, dejarás de recibir alertas y tu tutora no verá tu seguimiento académico. Podrás volver a aceptarlo cuando quieras.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Revocar')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await Api.revocarConsentimiento();
      await alRecargar();
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, mensajeError(e));
    }
  }

  Future<void> _aceptar(BuildContext context) async {
    try {
      await Api.aceptarConsentimiento();
      await alRecargar();
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = Map<String, dynamic>.from(resumen['estudiante'] as Map);
    final c = Map<String, dynamic>.from((resumen['consentimiento'] as Map?) ?? {});
    final activo = c['activo'] == true;
    return ListenableBuilder(
      listenable: ajustes,
      builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text('${e['nombres']}'),
            subtitle: Text('${e['codigo']} · ${e['carrera']} · ${e['ciclo']}.° ciclo'),
          ),
        ),
        Card(
          child: Column(children: [
            const ListTile(title: Text('Accesibilidad', style: TextStyle(fontWeight: FontWeight.bold))),
            SwitchListTile(value: ajustes.textoGrande, onChanged: ajustes.cambiarTexto, title: const Text('Texto más grande')),
            SwitchListTile(value: ajustes.altoContraste, onChanged: ajustes.cambiarContraste, title: const Text('Alto contraste')),
          ]),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Privacidad', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(activo ? 'Consentimiento: aceptado (versión 1.0)' : 'Consentimiento: revocado'),
              const SizedBox(height: 8),
              if (activo)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: colorAlto),
                  onPressed: () => _revocar(context),
                  child: const Text('Revocar consentimiento'),
                )
              else
                FilledButton(onPressed: () => _aceptar(context), child: const Text('Volver a aceptar')),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => Api.salir(), child: const Text('Cerrar sesión')),
      ]),
    );
  }
}

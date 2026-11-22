// Acceso a datos: usa las mismas tablas y funciones de Supabase que la web del PMV.
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get _db => Supabase.instance.client;

class Api {
  static Future<void> ingresar(String correo, String clave) async {
    await _db.auth.signInWithPassword(email: correo, password: clave);
  }

  static Future<void> salir() async {
    await _db.auth.signOut();
  }

  static bool get haySesion => _db.auth.currentSession != null;

  static Future<Map<String, dynamic>> perfil() async {
    final usuario = _db.auth.currentUser;
    if (usuario == null) {
      throw Exception('Sesión no iniciada');
    }
    final datos = await _db.from('perfiles').select('id,correo,nombres,rol').eq('id', usuario.id).single();
    return Map<String, dynamic>.from(datos);
  }

  static Future<Map<String, dynamic>> resumen() async {
    final datos = await _db.rpc('mi_resumen');
    return Map<String, dynamic>.from(datos as Map);
  }

  static Future<void> aceptarConsentimiento() async {
    await _db.rpc('aceptar_consentimiento');
  }

  static Future<void> revocarConsentimiento() async {
    await _db.rpc('revocar_consentimiento');
  }

  static Future<void> marcarLeida(int id) async {
    await _db.rpc('marcar_alerta_leida', params: {'p_id': id});
  }

  static Future<void> guardarTest({
    required Map<String, String> respuestas,
    required int avance,
    required bool completado,
    String? resultado,
    required bool compartir,
  }) async {
    await _db.rpc('guardar_test', params: {
      'p_respuestas': respuestas,
      'p_avance': avance,
      'p_completado': completado,
      'p_resultado': resultado,
      'p_compartir': compartir,
    });
  }
}

String mensajeError(Object e) {
  String m;
  if (e is AuthException) {
    m = e.message;
  } else if (e is PostgrestException) {
    m = e.message;
  } else {
    m = e.toString();
  }
  if (m.contains('Invalid login credentials')) return 'Correo o contraseña incorrectos.';
  if (m.contains('SIN_CONSENTIMIENTO')) return 'Primero debes aceptar el consentimiento.';
  if (m.contains('SocketException') || m.contains('Failed host lookup') || m.contains('ClientException')) {
    return 'No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.';
  }
  if (m.contains('Invalid path') || m.contains('Invalid API key') || m.contains('No API key')) {
    return 'La app no está bien configurada (revisa la dirección y la clave de Supabase en config.dart).';
  }
  return m;
}

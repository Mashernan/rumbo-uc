# RUMBO_UC · App móvil del estudiante (Flutter · Android)

Esta app es la versión nativa para Android de la app del estudiante. Se conecta a **la misma base de Supabase** que ya usa la plataforma web, así que las cuentas, las alertas y los resultados del test son los mismos.

| Pantalla | Historia | Estado |
|---|---|---|
| Ingreso con correo y contraseña | HU15 | Real |
| Consentimiento informado | HU15 | Real |
| Inicio con alerta temprana | HU03 | Real |
| Detalle de la alerta y recomendaciones | HU03 | Real |
| Test de orientación (guardar y continuar) | HU05 | Real |
| Resultado y permiso para compartir | HU05, HU17 | Real |
| Perfil: texto grande, alto contraste, revocar consentimiento | HU17, HU18 | Real |
| Tutoría y Comunidad | HU08, HU09, HU11–HU13 | Release 2 (abre el prototipo) |

No necesitan instalar Flutter ni Android Studio: **GitHub compila el .apk en la nube**.

---

## Paso 1. Pegar la conexión a Supabase

1. Abran `app_movil/lib/config.dart` con el Bloc de notas o VS Code.
2. Reemplacen los dos textos `PEGAR-AQUI` con **los mismos valores** que ya pusieron en `config.js` de la web:
   - `supabaseUrl`: la URL del proyecto, por ejemplo `https://abcd1234.supabase.co` (sin `/rest/v1` al final).
   - `supabaseKey`: la clave **anon / publishable**.
3. Guarden el archivo.

> ⚠️ Nunca peguen la clave **secret** ni la **service_role**. El repositorio es público.

## Paso 2. Subir los archivos al repositorio

1. En GitHub, entren al repositorio `rumbo-uc` → **Add file → Upload files**.
2. Arrastren **la carpeta `app_movil` completa** (no los archivos sueltos).
3. Mensaje del commit: `Agrega app movil Flutter` → **Commit changes**.

## Paso 3. Crear la compilación automática

1. En el repositorio, vayan a la pestaña **Actions**.
2. Hagan clic en **set up a workflow yourself** (si ya hay flujos, primero **New workflow**).
3. Arriba, en el nombre del archivo, escriban: `build-apk.yml`
4. Borren el contenido de ejemplo y peguen todo el contenido del archivo `.github/workflows/build-apk.yml` que viene en este paquete.
5. **Commit changes…** → **Commit changes**.

Al guardar, la compilación arranca sola. También pueden lanzarla a mano: **Actions → Compilar APK RUMBO_UC → Run workflow**.

## Paso 4. Descargar el APK

1. En **Actions**, entren a la ejecución más reciente. Tarda unos 6 a 10 minutos.
2. Si sale con ✅ verde, bajen hasta **Artifacts** y descarguen **RUMBO_UC-apk** (es un .zip).
3. Descompriman: dentro está `app-release.apk`.

Si sale con ❌ rojo: entren al paso que falló, copien las últimas líneas del mensaje y envíenselas a Claude para corregirlo.

## Paso 5. Instalar en un celular Android

1. Pasen `app-release.apk` al celular (WhatsApp a sí mismos, Drive o cable).
2. Ábranlo. Android pedirá permitir **instalar apps de origen desconocido** para esa aplicación: acepten.
3. Si aparece Play Protect, elijan **Instalar de todas formas** (es normal en apps que no están en Play Store).
4. Ingresen con `estudiante@rumbo.test` y la contraseña del equipo.

## Prueba rápida (antes de grabar el video)

1. Ejecuten `supabase/02_usuarios_demo.sql` en Supabase para dejar los datos de demostración limpios.
2. Ingresen en la app → acepten el consentimiento → deben ver **«Tienes una alerta nueva»** con riesgo alto.
3. Toquen la alerta: deben aparecer asistencia 62 %, promedio 10.4, 2 evaluaciones por reforzar.
4. Respondan 3 preguntas del test, cierren la app y vuelvan a abrirla: el avance debe conservarse.
5. En **Perfil**, activen *Texto más grande* y *Alto contraste*.
6. En la web, con `tutora@rumbo.test`, verifiquen que Lucía figura con su avance del test.

## Archivos

```
app_movil/
├── pubspec.yaml          dependencias (supabase_flutter, url_launcher)
├── lib/config.dart       URL y clave pública de Supabase  ← editar
├── lib/api.dart          llamadas a Supabase (mismas funciones RPC que la web)
├── lib/datos.dart        preguntas del test y cálculo del resultado
├── lib/main.dart         pantallas
├── test/widget_test.dart pruebas del cálculo del test
└── icono/                íconos del launcher
```

La carpeta `android/` no se sube: la genera GitHub Actions en cada compilación con `flutter create`.

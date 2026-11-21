# RUMBO_UC · Producto mínimo viable (Release 1)

Plataforma de alertas tempranas de riesgo académico para estudiantes de primeros ciclos.
Proyecto académico del curso Taller de Proyectos II. Todos los nombres y datos son ficticios.

## Qué incluye

| Archivo | Para qué sirve |
|---|---|
| `index.html` | Página de inicio del PMV, con enlaces a la app, la web y el prototipo |
| `app.html` | App del estudiante (instalable en el celular) |
| `web.html` | Plataforma web: tutora, Coordinación de Bienestar y TI |
| `prototipo.html` | Prototipo navegable de las 28 interfaces (incluye el Release 2) |
| `config.js` | Datos de conexión a Supabase (**se edita una vez**) |
| `supabase/01_esquema.sql` | Crea la base de datos, la seguridad por rol y los datos de demostración |
| `supabase/02_usuarios_demo.sql` | Asigna los roles a las 4 cuentas de prueba |
| `ejemplos/*.csv` | Archivos para probar la importación de notas (HU01) |

Historias de usuario que funcionan con datos reales: HU15, HU01, HU05, HU02, HU17, HU06, HU03, HU07 y HU04.

Si `config.js` está vacío, todo funciona en **modo demostración** (los datos se guardan solo en ese navegador).

---

## Paso 1 · Crear la base de datos en Supabase (15 min)

1. Entra a https://supabase.com y crea una cuenta gratuita (puedes usar tu cuenta de GitHub).
2. **New project** → nombre `rumbo-uc` → crea una contraseña para la base de datos (guárdala) → región **South America (São Paulo)** → **Create new project**. Espera unos 2 minutos.
3. Menú izquierdo → **SQL Editor** → **New query**. Abre `supabase/01_esquema.sql`, copia **todo** su contenido, pégalo y presiona **Run**. Debe terminar con «Success».
4. Menú izquierdo → **Authentication** → **Users** → **Add user** → **Create new user**. Crea estos 4 usuarios, con la misma contraseña para todos (por ejemplo `Rumbo2026!`) y marcando **Auto Confirm User**:
   - `estudiante@rumbo.test`
   - `tutora@rumbo.test`
   - `coordinacion@rumbo.test`
   - `ti@rumbo.test`

   Si Supabase no acepta esos correos, usen correos propios y cámbienlos en las líneas 7 a 10 de `02_usuarios_demo.sql`.
5. Vuelve a **SQL Editor** → **New query** → pega todo `supabase/02_usuarios_demo.sql` → **Run**. Debe mostrar «Listo: 41 estudiantes…».

## Paso 2 · Conectar la aplicación (2 min)

1. En Supabase: **Project Settings** (engranaje) → **API** (o **Data API**).
2. Copia **Project URL** y la clave **anon public**.
3. Abre `config.js` y pégalas entre las comillas:

```js
window.RUMBO_CONFIG = {
  url: "https://xxxxxxxx.supabase.co",
  anonKey: "eyJhbGciOi..."
};
```

La clave *anon* es pública por diseño: la seguridad la dan las reglas por rol (RLS) que crea el script 1.
**Nunca** pongan aquí la clave *service_role*.

## Paso 3 · Publicar en GitHub Pages (5 min)

1. En GitHub: **New repository** → nombre `rumbo-uc` → **Public** → **Create repository**.
2. **uploading an existing file** → arrastra **todo el contenido** de esta carpeta (con las carpetas `assets`, `supabase` y `ejemplos`) → **Commit changes**.
3. **Settings** → **Pages** → Branch: `main` y carpeta `/ (root)` → **Save**.
4. En 1 o 2 minutos el PMV estará en `https://TU-USUARIO.github.io/rumbo-uc/`.

## Paso 4 · Probar (5 min)

En la parte superior debe aparecer **«Conectado a Supabase»**. Si dice «Modo demostración», revisa `config.js`.

| Prueba | Cómo | Resultado esperado |
|---|---|---|
| HU15 | App → ingresar como `estudiante@rumbo.test` | Pide el consentimiento; el botón se activa al marcar la casilla |
| HU03 | Aceptar el consentimiento | Aparece la alerta de riesgo alto con recomendaciones |
| HU05 | Responder 5 preguntas del test → «Guardar y continuar después» → volver | Retoma en la pregunta 6 |
| HU06 / HU02 | Web → `tutora@rumbo.test` | 40 tutorados ordenados por riesgo; al abrir uno se ven sus factores |
| HU17 | En el dashboard, «abrir el estudiante U202609911» | «Acceso denegado» y el intento aparece en la auditoría |
| HU07 | Registrar una tutoría con menos de 20 caracteres | Mensaje de validación; con texto válido se guarda |
| HU04 | Web → Avisos | Un aviso «Escalado» (más de 72 h) y otros «Pendiente» |
| HU01 | Web → `ti@rumbo.test` → subir `ejemplos/notas_con_errores.csv` | Rechaza 4 filas y no carga nada |
| HU01 | Subir `ejemplos/notas_validas.csv` | Procesa 6 filas; Valeria Torres pasa a riesgo alto y la tutora recibe un aviso |
| HU02 | Web → `coordinacion@rumbo.test` → Reglas → pesos que no suman 100 | Rechaza el cambio; con pesos válidos recalcula el semáforo |

Para **reiniciar la demostración** (por ejemplo, antes de grabar el video), vuelvan a ejecutar `02_usuarios_demo.sql`.

## Instalar la app en el celular

Abre `https://TU-USUARIO.github.io/rumbo-uc/app.html` en el celular:
- **Android (Chrome):** menú ⋮ → **Instalar aplicación** o **Agregar a pantalla de inicio**.
- **iPhone (Safari):** botón Compartir → **Agregar a inicio**.

Aparece el ícono de RUMBO_UC y la app se abre a pantalla completa.

## Notas técnicas para el informe

- **PMV:** HTML, CSS y JavaScript sin frameworks, más Supabase (PostgreSQL 15+, autenticación y API REST automática). La arquitectura objetivo del Ítem 5 (Flutter, React y NestJS) se mantiene para las siguientes versiones; el PMV valida la hipótesis con el menor costo.
- **Seguridad (HU17):** Row Level Security en todas las tablas; las operaciones sensibles (importación, reglas, detalle del estudiante) son funciones de la base de datos que verifican el rol y registran la auditoría.
- **Lógica de negocio en la base de datos:** el cálculo del riesgo, las alertas, el escalamiento a 72 h y la validación «todo o nada» del CSV están en `01_esquema.sql`, así que no se pueden saltar desde el navegador.
- **Plan gratuito de Supabase:** el proyecto se pausa tras 7 días sin uso. Si al abrir el PMV aparece un error de conexión, entren a supabase.com y presionen **Restore project**.

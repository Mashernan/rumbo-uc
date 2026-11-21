/* RUMBO_UC · PMV · utilidades y capa de acceso a datos
   - Con config.js completo: usa Supabase (datos reales compartidos).
   - Sin config.js o con #demo en la URL: modo demostración (datos ficticios guardados en este navegador). */
"use strict";
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const go = h => { if (location.hash === "#" + h) window.render && window.render(); else location.hash = h; };
const fmtFecha = d => d ? new Date(d).toLocaleString("es-PE", {day:"2-digit", month:"2-digit", year:"numeric", hour:"2-digit", minute:"2-digit"}) : "—";
const fmtDia = d => d ? new Date(String(d).length === 10 ? d + "T12:00:00" : d).toLocaleDateString("es-PE", {day:"2-digit", month:"2-digit", year:"numeric"}) : "—";
const hoyISO = () => { const d = new Date(); d.setMinutes(d.getMinutes() - d.getTimezoneOffset()); return d.toISOString().slice(0, 10); };
const NIVEL_TXT = {alto:"Riesgo alto", medio:"Riesgo medio", bajo:"Riesgo bajo"};
const lvl = n => n ? `<span class="chip ${n}"><span class="dot ${n}" aria-hidden="true"></span>${NIVEL_TXT[n]}</span>` : '<span class="chip neutral">Sin cálculo</span>';
const spinner = (t = "Cargando…") => `<div class="loading" role="status"><span class="spin" aria-hidden="true"></span>${esc(t)}</div>`;

function toast(msg){ let l = $("#toasts"); if(!l){ l = document.createElement("div"); l.id = "toasts"; l.setAttribute("aria-live","polite"); document.body.appendChild(l); }
  const t = document.createElement("div"); t.className = "toast"; t.setAttribute("role","status"); t.textContent = msg; l.appendChild(t); setTimeout(() => t.remove(), 3800); }
function modal(title, bodyHTML, actions){
  const bg = document.createElement("div"); bg.className = "modal-bg";
  bg.innerHTML = `<div class="modal" role="dialog" aria-modal="true" aria-labelledby="mdl-t"><h2 id="mdl-t">${title}</h2><div>${bodyHTML}</div><div class="row" style="justify-content:flex-end;margin-top:1rem" id="mdl-a"></div></div>`;
  (actions || [{label:"Cerrar"}]).forEach(a => { const b = document.createElement("button"); b.className = "btn " + (a.cls || ""); b.textContent = a.label;
    b.onclick = async () => { if (a.fn) { b.disabled = true; const r = await a.fn(bg); b.disabled = false; if (r === false) return; } bg.remove(); }; $("#mdl-a", bg).appendChild(b); });
  bg.addEventListener("keydown", e => { if (e.key === "Escape") bg.remove(); });
  document.body.appendChild(bg); const f = $(".modal input,.modal textarea,.modal select", bg) || $("#mdl-a button", bg); f && f.focus(); return bg;
}
function setErr(input, msg){
  const id = input.id + "-err"; let e = document.getElementById(id);
  if (!msg) { input.removeAttribute("aria-invalid"); if (e) e.remove(); return true; }
  input.setAttribute("aria-invalid", "true"); input.setAttribute("aria-describedby", id);
  if (!e) { e = document.createElement("div"); e.className = "err"; e.id = id; e.setAttribute("role", "alert"); input.insertAdjacentElement("afterend", e); }
  e.textContent = msg; return false;
}
const local = { get(k, d){ try { const v = localStorage.getItem("rumbopmv_" + k); return v ? JSON.parse(v) : d; } catch (e) { return d; } },
                set(k, v){ try { localStorage.setItem("rumbopmv_" + k, JSON.stringify(v)); } catch (e) {} },
                del(k){ try { localStorage.removeItem("rumbopmv_" + k); } catch (e) {} } };
function initA11y(){
  const sz = $("#tg-size"), hc = $("#tg-hc");
  const setSize = v => { document.documentElement.classList.toggle("lg", v); sz && sz.setAttribute("aria-pressed", v); local.set("lg", v); };
  const setHC = v => { document.body.classList.toggle("hc", v); hc && hc.setAttribute("aria-pressed", v); local.set("hc", v); };
  setSize(local.get("lg", false)); setHC(local.get("hc", false));
  if (sz) sz.onclick = () => setSize(!document.documentElement.classList.contains("lg"));
  if (hc) hc.onclick = () => setHC(!document.body.classList.contains("hc"));
  return {setSize, setHC};
}
const ERRORES = {
  ACCESO_DENEGADO: "No tienes permiso para realizar esta acción.", SIN_CONSENTIMIENTO: "Primero debes aceptar el consentimiento.",
  PESOS_DEBEN_SUMAR_100: "Los pesos deben sumar 100 %.", UMBRAL_FUERA_DE_RANGO: "Algún umbral está fuera del rango permitido.",
  ARCHIVO_VACIO: "El archivo no tiene filas de datos.", ARCHIVO_DEMASIADO_GRANDE: "El archivo supera las 20 000 filas.",
  ALERTA_NO_DISPONIBLE: "El aviso ya fue atendido o no te corresponde.", "Invalid login credentials": "Correo o contraseña incorrectos.",
  "row-level security": "No tienes permiso para registrar esta información."
};
function msgError(e){ const m = (e && (e.message || e.error_description || String(e))) || "Error desconocido";
  for (const k in ERRORES) if (m.includes(k)) return ERRORES[k];
  if (/fetch|network/i.test(m)) return "No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.";
  return m; }

/* ===================== Backend Supabase ===================== */
function SupabaseApi(cfg){
  const sb = window.supabase.createClient(cfg.url, cfg.anonKey, {auth:{persistSession:true, storageKey:"rumbopmv-auth"}});
  const ok = ({data, error}) => { if (error) throw error; return data; };
  let perfilCache = null;
  return {
    modo: "supabase",
    async usuario(){ const {data} = await sb.auth.getSession(); if (!data.session) return null;
      if (perfilCache && perfilCache.id === data.session.user.id) return perfilCache;
      perfilCache = ok(await sb.from("perfiles").select("id,correo,nombres,rol").eq("id", data.session.user.id).single()); return perfilCache; },
    async login(email, pass){ ok(await sb.auth.signInWithPassword({email, password:pass})); perfilCache = null; return this.usuario(); },
    async logout(){ perfilCache = null; await sb.auth.signOut(); },
    miResumen: async () => ok(await sb.rpc("mi_resumen")),
    aceptarConsentimiento: async () => ok(await sb.rpc("aceptar_consentimiento")),
    revocarConsentimiento: async () => ok(await sb.rpc("revocar_consentimiento")),
    marcarLeida: async id => ok(await sb.rpc("marcar_alerta_leida", {p_id:id})),
    guardarTest: async t => ok(await sb.rpc("guardar_test", {p_respuestas:t.respuestas, p_avance:t.avance, p_completado:t.completado, p_resultado:t.resultado || null, p_compartir:!!t.compartir})),
    riesgoActual: async () => ok(await sb.from("v_riesgo_actual").select("*")),
    verEstudiante: async id => ok(await sb.rpc("ver_estudiante", {p_id:id})),
    registrarTutoria: async t => ok(await sb.from("tutorias").insert({id_estudiante:t.id_estudiante, fecha:t.fecha, modalidad:t.modalidad, acuerdos:t.acuerdos, fecha_seguimiento:t.fecha_seguimiento || null})),
    avisos: async () => ok(await sb.from("v_avisos").select("*").order("fecha_envio", {ascending:true})),
    atenderAlerta: async id => ok(await sb.rpc("atender_alerta", {p_id:id})),
    reglas: async () => ok(await sb.from("reglas_riesgo").select("*").single()),
    guardarReglas: async r => ok(await sb.rpc("guardar_reglas", {p_asist:r.umbral_asistencia, p_prom:r.umbral_promedio, p_desap:r.umbral_desaprobadas, p_inact:r.umbral_inactividad,
      p_w_asist:r.peso_asistencia, p_w_prom:r.peso_promedio, p_w_desap:r.peso_desaprobadas, p_w_inact:r.peso_inactividad})),
    auditoria: async () => ok(await sb.from("auditoria").select("*").order("fecha", {ascending:false}).limit(200)),
    cargas: async () => ok(await sb.from("cargas_datos").select("*").order("fecha", {ascending:false}).limit(50)),
    importar: async (filas, archivo) => ok(await sb.rpc("importar_datos", {p_filas:filas, p_archivo:archivo})),
    registrarDenegado: async r => { try { ok(await sb.rpc("registrar_denegado", {p_recurso:r})); } catch (e) {} }
  };
}

/* ===================== Backend de demostración (mismas reglas que la base de datos) ===================== */
function DemoApi(){
  const KEY = "demo_db";
  const USERS = [
    {id:"u-est", correo:"estudiante@rumbo.test", nombres:"Lucía Ramos", rol:"estudiante"},
    {id:"u-tut", correo:"tutora@rumbo.test", nombres:"Ing. Rosa Quispe", rol:"tutor"},
    {id:"u-coord", correo:"coordinacion@rumbo.test", nombres:"Lic. Martha Ccahuana", rol:"coordinador"},
    {id:"u-ti", correo:"ti@rumbo.test", nombres:"Jorge Pariona", rol:"ti"}];
  const CURSOS = ["Matemática Básica","Comunicación","Fundamentos de Programación","Física I","Química General","Introducción a la Ingeniería"];
  const CARRERAS = ["Ing. de Sistemas","Ing. Industrial"];
  const NOMBRES = ["Lucía Ramos","Diego Huamán","Valeria Torres","Joaquín Paredes","Camila Rojas","Mateo Quispe","Ariana Salazar","Sebastián Lazo","Fernanda Ccori","Rodrigo Medina","Daniela Ponce","Gabriel Inga","Mariana Vega","Thiago Cárdenas","Ximena Arias","Bruno Espinoza","Antonella Ríos","Adrián Soto","Luana Mendoza","Iker Flores","Renata Chávez","Samuel Ortiz","Abril Castro","Leonardo Vargas","Micaela Núñez","Gael Palomino","Zoe Aquino","Emilio Benavides","Alessia Ruiz","Facundo Tello","Isabella Cruz","Matías Gamarra","Julieta Montes","Santiago Rivas","Kiara Lozano","Nicolás Yupanqui","Ainhoa Campos","Dylan Mamani","Ariadna León","Franco Villena","Estudiante de otro tutor"];
  const now = () => new Date().toISOString();
  const diasAtras = n => { const d = new Date(); d.setDate(d.getDate() - n); return d.toISOString().slice(0, 10); };
  const horasAtras = h => new Date(Date.now() - h * 3600e3).toISOString();
  let db;
  function rng(seed){ return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
  function seed(){
    const r = rng(42); db = {seq:1, estudiantes:[], matriculas:[], notas:[], indicadores:[], alertas:[], tutorias:[], tests:{}, consentimientos:[], auditoria:[], cargas:[],
      reglas:{umbral_asistencia:75, umbral_promedio:11, umbral_desaprobadas:2, umbral_inactividad:7, peso_asistencia:35, peso_promedio:30, peso_desaprobadas:20, peso_inactividad:15}, sesion:null};
    NOMBRES.forEach((n, k) => { const i = k + 1; const perfil = i === 1 ? 3 : i === 41 ? 0 : (i * 7) % 4;
      const e = {id:i, codigo: i === 41 ? "U202609911" : "U2026" + String(1000 + (i - 1) * 37).padStart(5, "0"), nombres:n, carrera:CARRERAS[i % 2], ciclo:1 + (i % 2),
        id_tutor: i === 41 ? null : "u-tut", id_usuario: i === 1 ? "u-est" : null,
        ultimo_acceso: diasAtras(perfil === 3 ? 8 + Math.floor(r() * 6) : perfil === 2 ? 3 + Math.floor(r() * 6) : Math.floor(r() * 4))};
      db.estudiantes.push(e);
      for (let c = 1; c <= 3; c++) { const as = perfil === 3 ? 58 + r() * 14 : perfil === 2 ? 68 + r() * 14 : 82 + r() * 17;
        const m = {id:db.seq++, id_estudiante:i, curso:CURSOS[(i + c * 2) % 6], periodo:"2026-2", asistencia:Math.round(as * 10) / 10}; db.matriculas.push(m);
        ["PC1","PC2","PC3"].forEach(ev => { const nt = perfil === 3 ? 6 + r() * 6 : perfil === 2 ? 9 + r() * 5 : 12 + r() * 7; db.notas.push({id:db.seq++, id_matricula:m.id, evaluacion:ev, valor:Math.round(nt * 10) / 10}); }); } });
    const lu = db.estudiantes[0]; lu.ultimo_acceso = diasAtras(5);
    db.matriculas.filter(m => m.id_estudiante === 1).forEach((m, k) => { m.asistencia = 62; db.notas.filter(n => n.id_matricula === m.id).forEach(n => n.valor = k === 0 && n.evaluacion !== "PC1" ? 9 : 10.8); });
    recalcular(null);
    db.indicadores.slice().forEach(i => [[14, Math.max(0, i.puntaje - 30 + (i.id % 3) * 5)], [7, Math.max(0, i.puntaje - 15 + (i.id % 2) * 5)]].forEach(([d, p]) =>
      db.indicadores.push({id:db.seq++, id_estudiante:i.id_estudiante, puntaje:p, nivel:p >= 60 ? "alto" : p >= 30 ? "medio" : "bajo", factores:i.factores, fecha_calculo:horasAtras(d * 24)})));
    const tv = db.alertas.filter(a => a.tipo === "tutor" && a.id_estudiante !== 1);
    if (tv[0]) tv[0].fecha_envio = horasAtras(80); if (tv[1]) tv[1].fecha_envio = horasAtras(50);
    save();
  }
  const save = () => local.set(KEY, db);
  const load = () => { db = local.get(KEY, null); if (!db || !db.estudiantes) seed(); };
  const yo = () => USERS.find(u => u.id === db.sesion) || null;
  const rol = () => (yo() || {}).rol;
  const correo = () => (yo() || {}).correo;
  const auditar = (accion, recurso, resultado) => { db.auditoria.unshift({id:db.seq++, correo:correo(), accion, recurso, resultado, fecha:now()}); };
  const consent = uid => db.consentimientos.some(c => c.id_usuario === uid && !c.fecha_revocacion);
  const ultimo = id => db.indicadores.filter(i => i.id_estudiante === id).sort((a, b) => b.fecha_calculo.localeCompare(a.fecha_calculo) || b.id - a.id)[0];
  const err = m => { throw new Error(m); };
  function factores(e){ const R = db.reglas; const ms = db.matriculas.filter(m => m.id_estudiante === e.id); const per = ms.map(m => m.periodo).sort().pop();
    const mm = ms.filter(m => m.periodo === per); const ns = db.notas.filter(n => mm.some(m => m.id === n.id_matricula));
    const asist = mm.length ? mm.reduce((a, m) => a + m.asistencia, 0) / mm.length : 100; const prom = ns.length ? ns.reduce((a, n) => a + n.valor, 0) / ns.length : 20;
    const desap = ns.filter(n => n.valor < 10.5).length; const inact = Math.max(0, Math.round((new Date(hoyISO()) - new Date(e.ultimo_acceso)) / 864e5));
    const r1 = x => Math.round(x * 10) / 10;
    return {asistencia:{valor:r1(asist), umbral:R.umbral_asistencia, fuera:asist < R.umbral_asistencia, peso:R.peso_asistencia},
      promedio:{valor:r1(prom), umbral:R.umbral_promedio, fuera:prom < R.umbral_promedio, peso:R.peso_promedio},
      desaprobadas:{valor:desap, umbral:R.umbral_desaprobadas, fuera:desap >= R.umbral_desaprobadas, peso:R.peso_desaprobadas},
      inactividad:{valor:inact, umbral:R.umbral_inactividad, fuera:inact >= R.umbral_inactividad, peso:R.peso_inactividad}}; }
  function recalcular(carga){ let n = 0; const hoy = hoyISO();
    db.estudiantes.forEach(e => { const f = factores(e); const sc = Object.values(f).reduce((a, x) => a + (x.fuera ? x.peso : 0), 0);
      const nv = sc >= 60 ? "alto" : sc >= 30 ? "medio" : "bajo"; const prev = ultimo(e.id);
      const ind = {id:db.seq++, id_estudiante:e.id, id_carga:carga, puntaje:sc, nivel:nv, factores:f, fecha_calculo:now()}; db.indicadores.push(ind);
      if ((nv === "medio" || nv === "alto") && (!prev || prev.nivel !== nv)) {
        if (e.id_usuario && consent(e.id_usuario) && !db.alertas.some(a => a.id_estudiante === e.id && a.tipo === "estudiante" && a.fecha_envio.slice(0, 10) === hoy)) {
          db.alertas.push({id:db.seq++, id_indicador:ind.id, id_estudiante:e.id, destinatario:e.id_usuario, tipo:"estudiante", nivel:nv, estado:"enviada", fecha_envio:now()}); n++; }
        if (nv === "alto" && e.id_tutor && !db.alertas.some(a => a.id_estudiante === e.id && a.tipo === "tutor" && a.estado !== "atendida")) {
          db.alertas.push({id:db.seq++, id_indicador:ind.id, id_estudiante:e.id, destinatario:e.id_tutor, tipo:"tutor", nivel:nv, estado:"enviada", fecha_envio:now()}); n++; } } });
    return n; }
  const visibles = () => { const r = rol(), u = db.sesion; return db.estudiantes.filter(e => r === "coordinador" || r === "ti" || e.id_tutor === u || e.id_usuario === u); };
  function fila(e){ const i = ultimo(e.id); const hist = db.indicadores.filter(x => x.id_estudiante === e.id).sort((a, b) => b.fecha_calculo.localeCompare(a.fecha_calculo) || b.id - a.id).slice(0, 5).reverse().map(x => x.puntaje);
    const crit = db.matriculas.filter(m => m.id_estudiante === e.id).sort((a, b) => a.asistencia - b.asistencia)[0];
    return {id:e.id, codigo:e.codigo, nombres:e.nombres, carrera:e.carrera, ciclo:e.ciclo, nivel:i && i.nivel, puntaje:i && i.puntaje, factores:i && i.factores, fecha_calculo:i && i.fecha_calculo,
      asistencia:i && i.factores.asistencia.valor, promedio:i && i.factores.promedio.valor, curso_critico:crit && crit.curso, historial:hist}; }
  const tick = () => new Promise(r => setTimeout(r, 120));
  load();
  const api = {
    modo: "demo", USERS,
    reiniciar(){ local.del(KEY); seed(); },
    async usuario(){ return yo(); },
    async login(email, pass){ await tick(); const u = USERS.find(x => x.correo === String(email).trim().toLowerCase()); if (!u || !pass) err("Invalid login credentials"); db.sesion = u.id; save(); return u; },
    async logout(){ db.sesion = null; save(); },
    async miResumen(){ await tick(); const e = db.estudiantes.find(x => x.id_usuario === db.sesion); if (!e) return {estudiante:null}; const act = consent(db.sesion); const i = ultimo(e.id);
      const crit = db.matriculas.filter(m => m.id_estudiante === e.id).sort((a, b) => a.asistencia - b.asistencia)[0];
      return {estudiante:{codigo:e.codigo, nombres:e.nombres, carrera:e.carrera, ciclo:e.ciclo},
        consentimiento:{activo:act, revocado:!act && db.consentimientos.some(c => c.id_usuario === db.sesion && c.fecha_revocacion)},
        riesgo: act && i ? {nivel:i.nivel, factores:i.factores, fecha:i.fecha_calculo} : null,
        alertas: act ? db.alertas.filter(a => a.destinatario === db.sesion && a.tipo === "estudiante").sort((a, b) => b.fecha_envio.localeCompare(a.fecha_envio)).map(a => ({id:a.id, nivel:a.nivel, fecha:a.fecha_envio, leida:a.estado !== "enviada"})) : [],
        tutor:"Ing. Rosa Quispe", curso_critico:crit && crit.curso, test:db.tests[e.id] || null}; },
    async aceptarConsentimiento(){ await tick(); if (!consent(db.sesion)) { db.consentimientos.push({id:db.seq++, id_usuario:db.sesion, version:"1.0", fecha_aceptacion:now(), fecha_revocacion:null}); auditar("Aceptar consentimiento", "versión 1.0", "Permitido"); }
      const e = db.estudiantes.find(x => x.id_usuario === db.sesion); if (e) { const i = ultimo(e.id);
        if (i && i.nivel !== "bajo" && !db.alertas.some(a => a.id_estudiante === e.id && a.tipo === "estudiante" && a.fecha_envio.slice(0, 10) === hoyISO()))
          db.alertas.push({id:db.seq++, id_indicador:i.id, id_estudiante:e.id, destinatario:db.sesion, tipo:"estudiante", nivel:i.nivel, estado:"enviada", fecha_envio:now()}); }
      save(); },
    async revocarConsentimiento(){ await tick(); db.consentimientos.filter(c => c.id_usuario === db.sesion && !c.fecha_revocacion).forEach(c => c.fecha_revocacion = now()); auditar("Revocar consentimiento", "versión 1.0", "Permitido"); save(); },
    async marcarLeida(id){ const a = db.alertas.find(x => x.id === id && x.destinatario === db.sesion && x.estado === "enviada"); if (a) { a.estado = "leida"; save(); } },
    async guardarTest(t){ const e = db.estudiantes.find(x => x.id_usuario === db.sesion); if (!e) err("SOLO_ESTUDIANTES"); if (!consent(db.sesion)) err("SIN_CONSENTIMIENTO");
      db.tests[e.id] = {respuestas:t.respuestas, avance:t.avance, completado:t.completado, resultado:t.resultado || null, compartir:!!t.compartir, actualizado:now()}; save(); },
    async riesgoActual(){ await tick(); return visibles().map(fila); },
    async verEstudiante(id){ await tick(); const e = db.estudiantes.find(x => x.id === id); const r = rol();
      if (!(r === "coordinador" || (r === "tutor" && e && e.id_tutor === db.sesion))) { auditar("Ver detalle de estudiante", e ? e.codigo : "id " + id, "Denegado"); save(); return {denegado:true}; }
      auditar("Ver detalle de estudiante", e.codigo, "Permitido"); save(); const f = fila(e); const t = db.tests[id];
      return {estudiante:f, factores:f.factores, tutorias:db.tutorias.filter(x => x.id_estudiante === id).sort((a, b) => b.fecha.localeCompare(a.fecha) || b.id - a.id).map(x => ({fecha:x.fecha, modalidad:x.modalidad, acuerdos:x.acuerdos, seguimiento:x.fecha_seguimiento})),
        test: t ? {completado:t.completado, compartido:t.compartir, resultado:t.compartir ? t.resultado : null} : null}; },
    async registrarTutoria(t){ await tick(); const e = db.estudiantes.find(x => x.id === t.id_estudiante);
      if (rol() !== "tutor" || !e || e.id_tutor !== db.sesion) err("new row violates row-level security policy");
      if (t.fecha > hoyISO() || t.acuerdos.length < 20 || (t.fecha_seguimiento && t.fecha_seguimiento <= t.fecha)) err("Datos inválidos");
      db.tutorias.push(Object.assign({id:db.seq++, id_tutor:db.sesion, creado:now()}, t));
      db.alertas.filter(a => a.id_estudiante === e.id && a.tipo === "tutor" && a.estado !== "atendida").forEach(a => { a.estado = "atendida"; a.fecha_atencion = now(); }); save(); },
    async avisos(){ await tick(); const r = rol(); return db.alertas.filter(a => a.tipo === "tutor" && (a.destinatario === db.sesion || r === "coordinador")).sort((a, b) => a.fecha_envio.localeCompare(b.fecha_envio)).map(a => {
      const e = db.estudiantes.find(x => x.id === a.id_estudiante); const h = Math.round(((a.fecha_atencion ? new Date(a.fecha_atencion) : new Date()) - new Date(a.fecha_envio)) / 3600e3);
      return {id:a.id, id_estudiante:a.id_estudiante, codigo:e.codigo, nombres:e.nombres, nivel:a.nivel, fecha_envio:a.fecha_envio, horas:h, estado:a.estado === "atendida" ? "atendida" : h >= 72 ? "escalada" : "pendiente"}; }); },
    async atenderAlerta(id){ const a = db.alertas.find(x => x.id === id && x.tipo === "tutor" && x.estado !== "atendida" && (x.destinatario === db.sesion || rol() === "coordinador")); if (!a) err("ALERTA_NO_DISPONIBLE"); a.estado = "atendida"; a.fecha_atencion = now(); save(); },
    async reglas(){ return Object.assign({}, db.reglas); },
    async guardarReglas(R){ await tick(); if (rol() !== "coordinador") { auditar("Modificar reglas del semáforo", "reglas_riesgo", "Denegado"); save(); err("ACCESO_DENEGADO"); }
      if (R.umbral_asistencia < 50 || R.umbral_asistencia > 100 || R.umbral_promedio < 5 || R.umbral_promedio > 20 || R.umbral_desaprobadas < 1 || R.umbral_desaprobadas > 10 || R.umbral_inactividad < 1 || R.umbral_inactividad > 60) err("UMBRAL_FUERA_DE_RANGO");
      if (R.peso_asistencia + R.peso_promedio + R.peso_desaprobadas + R.peso_inactividad !== 100) err("PESOS_DEBEN_SUMAR_100");
      const antes = db.estudiantes.filter(e => (ultimo(e.id) || {}).nivel === "alto").length; Object.assign(db.reglas, R); recalcular(null);
      const despues = db.estudiantes.filter(e => (ultimo(e.id) || {}).nivel === "alto").length; auditar("Modificar reglas del semáforo", "reglas_riesgo", "Permitido"); save(); return {antes, despues}; },
    async auditoria(){ await tick(); if (!["ti","coordinador"].includes(rol())) return []; return db.auditoria.slice(0, 200); },
    async cargas(){ await tick(); if (!["ti","coordinador"].includes(rol())) return []; return db.cargas; },
    async importar(filas, archivo){ await tick(); if (rol() !== "ti") { auditar("Importar datos académicos", archivo, "Denegado"); save(); err("ACCESO_DENEGADO"); }
      if (!filas.length) err("ARCHIVO_VACIO"); const errs = []; const vistos = new Set();
      filas.forEach((f, k) => { const fila = k + 2; const nota = Number(f.nota), asis = Number(f.asistencia);
        const key = [String(f.codigo || "").toUpperCase(), String(f.curso || "").toLowerCase(), f.periodo, String(f.evaluacion || "").toUpperCase()].join("|");
        if (!/^U\d{9}$/.test(f.codigo || "")) errs.push({fila, motivo:"Código con formato inválido"});
        else if (!db.estudiantes.some(e => e.codigo === f.codigo)) errs.push({fila, motivo:"El código no corresponde a un estudiante registrado"});
        else if (!CURSOS.some(c => c.toLowerCase() === String(f.curso || "").toLowerCase())) errs.push({fila, motivo:"Curso no registrado"});
        else if (!/^\d{4}-[12]$/.test(f.periodo || "")) errs.push({fila, motivo:"Periodo inválido (formato 2026-2)"});
        else if (!String(f.evaluacion || "").trim()) errs.push({fila, motivo:"Evaluación vacía"});
        else if (f.nota === "" || isNaN(nota) || nota < 0 || nota > 20) errs.push({fila, motivo:"Nota fuera del rango 0–20"});
        else if (f.asistencia === "" || isNaN(asis) || asis < 0 || asis > 100) errs.push({fila, motivo:"Asistencia fuera del rango 0–100"});
        else if (vistos.has(key)) errs.push({fila, motivo:"Registro duplicado en el archivo"}); else vistos.add(key); });
      if (errs.length) { db.cargas.unshift({id:db.seq++, correo:correo(), archivo, fecha:now(), procesados:0, rechazados:errs.length}); auditar("Importar datos académicos (rechazada)", archivo, "Permitido"); save(); return {ok:false, errores:errs, rechazados:errs.length}; }
      const carga = {id:db.seq++, correo:correo(), archivo, fecha:now(), procesados:filas.length, rechazados:0};
      filas.forEach(f => { const e = db.estudiantes.find(x => x.codigo === f.codigo); const curso = CURSOS.find(c => c.toLowerCase() === f.curso.toLowerCase());
        let m = db.matriculas.find(x => x.id_estudiante === e.id && x.curso === curso && x.periodo === f.periodo);
        if (!m) { m = {id:db.seq++, id_estudiante:e.id, curso, periodo:f.periodo, asistencia:0}; db.matriculas.push(m); } m.asistencia = Number(f.asistencia);
        const ev = String(f.evaluacion).trim().toUpperCase(); const n = db.notas.find(x => x.id_matricula === m.id && x.evaluacion === ev);
        if (n) n.valor = Number(f.nota); else db.notas.push({id:db.seq++, id_matricula:m.id, evaluacion:ev, valor:Number(f.nota)});
        if (f.dias_sin_acceso !== undefined && f.dias_sin_acceso !== "" && !isNaN(Number(f.dias_sin_acceso))) e.ultimo_acceso = diasAtras(Number(f.dias_sin_acceso)); });
      db.cargas.unshift(carga); const alertas = recalcular(carga.id); auditar("Importar datos académicos", archivo, "Permitido"); save();
      return {ok:true, procesados:filas.length, rechazados:0, alertas}; },
    async registrarDenegado(r){ auditar("Abrir " + r, r, "Denegado"); save(); }
  };
  window.addEventListener("storage", e => { if (e.key === "rumbopmv_" + KEY) load(); });
  return api;
}

/* ===================== selección del backend ===================== */
function crearApi(){
  const cfg = window.RUMBO_CONFIG || {};
  const forzarDemo = /(^|[?&#])demo/.test(location.search + location.hash) || local.get("forzar_demo", false);
  if (!forzarDemo && cfg.url && cfg.anonKey && window.supabase && window.supabase.createClient) {
    try { return SupabaseApi(cfg); } catch (e) { console.warn("Supabase no disponible, se usa el modo demostración", e); }
  }
  return DemoApi();
}

/* ===================== CSV ===================== */
function parseCSV(texto){
  texto = texto.replace(/^﻿/, "");
  const primera = texto.split(/\r?\n/)[0] || ""; const sep = (primera.match(/;/g) || []).length > (primera.match(/,/g) || []).length ? ";" : ",";
  const filas = []; let fila = [], campo = "", q = false;
  for (let i = 0; i < texto.length; i++) { const c = texto[i];
    if (q) { if (c === '"') { if (texto[i + 1] === '"') { campo += '"'; i++; } else q = false; } else campo += c; }
    else if (c === '"') q = true; else if (c === sep) { fila.push(campo); campo = ""; }
    else if (c === "\n" || c === "\r") { if (c === "\r" && texto[i + 1] === "\n") i++; fila.push(campo); filas.push(fila); fila = []; campo = ""; }
    else campo += c; }
  if (campo !== "" || fila.length) { fila.push(campo); filas.push(fila); }
  const datos = filas.filter(f => f.some(x => x.trim() !== ""));
  if (!datos.length) return {cabecera:[], filas:[]};
  const cab = datos[0].map(h => h.trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, ""));
  return {cabecera:cab, filas:datos.slice(1).map(f => { const o = {}; cab.forEach((h, i) => o[h] = (f[i] || "").trim().replace(",", sep === ";" ? "." : ",")); return o; })};
}
const COLUMNAS_CSV = ["codigo","curso","periodo","evaluacion","nota","asistencia"];

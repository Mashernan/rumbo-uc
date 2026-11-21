-- =====================================================================
-- RUMBO_UC · PMV (Release 1) · Script 1 de 2: esquema, seguridad y datos de demo
-- Ejecutar completo en Supabase → SQL Editor → New query → Run.
-- Se puede volver a ejecutar: borra y recrea todo lo del PMV.
-- =====================================================================

-- ---------- limpieza (permite re-ejecutar) ----------
drop trigger if exists trg_crear_perfil on auth.users;
drop view if exists public.v_avisos, public.v_riesgo_actual cascade;
drop table if exists public.auditoria, public.consentimientos, public.tests_orientacion, public.tutorias,
  public.alertas, public.indicadores_riesgo, public.reglas_riesgo, public.cargas_datos, public.notas,
  public.matriculas, public.estudiantes, public.cursos, public.carreras, public.perfiles cascade;

-- ---------- tablas (modelo lógico del Ítem 5) ----------
create table public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  correo text not null,
  nombres text not null,
  rol text not null default 'estudiante' check (rol in ('estudiante','tutor','coordinador','ti')),
  creado timestamptz not null default now()
);
create table public.carreras (id serial primary key, nombre text not null unique);
create table public.cursos (id serial primary key, nombre text not null unique, id_carrera int references public.carreras(id), ciclo int not null default 1);
create table public.estudiantes (
  id serial primary key,
  codigo text not null unique check (codigo ~ '^U[0-9]{9}$'),
  nombres text not null,
  id_carrera int not null references public.carreras(id),
  ciclo int not null check (ciclo between 1 and 12),
  id_tutor uuid references public.perfiles(id),
  id_usuario uuid unique references public.perfiles(id),
  ultimo_acceso_aula date
);
create table public.matriculas (
  id serial primary key,
  id_estudiante int not null references public.estudiantes(id) on delete cascade,
  id_curso int not null references public.cursos(id),
  periodo text not null check (periodo ~ '^[0-9]{4}-[12]$'),
  asistencia numeric(5,2) not null default 100 check (asistencia between 0 and 100),
  unique (id_estudiante, id_curso, periodo)
);
create table public.notas (
  id serial primary key,
  id_matricula int not null references public.matriculas(id) on delete cascade,
  evaluacion text not null,
  valor numeric(4,2) not null check (valor between 0 and 20),
  fecha timestamptz not null default now(),
  unique (id_matricula, evaluacion)
);
create table public.cargas_datos (
  id serial primary key,
  id_usuario uuid references public.perfiles(id),
  correo text,
  archivo text not null,
  fecha timestamptz not null default now(),
  procesados int not null default 0,
  rechazados int not null default 0
);
create table public.reglas_riesgo (
  id int primary key default 1 check (id = 1),
  umbral_asistencia numeric not null, umbral_promedio numeric not null,
  umbral_desaprobadas int not null, umbral_inactividad int not null,
  peso_asistencia int not null, peso_promedio int not null, peso_desaprobadas int not null, peso_inactividad int not null,
  actualizado timestamptz not null default now(),
  check (peso_asistencia + peso_promedio + peso_desaprobadas + peso_inactividad = 100)
);
create table public.indicadores_riesgo (
  id serial primary key,
  id_estudiante int not null references public.estudiantes(id) on delete cascade,
  id_carga int references public.cargas_datos(id),
  puntaje int not null,
  nivel text not null check (nivel in ('bajo','medio','alto')),
  factores jsonb not null,
  fecha_calculo timestamptz not null default now()
);
create index on public.indicadores_riesgo (id_estudiante, fecha_calculo desc);
create table public.alertas (
  id serial primary key,
  id_indicador int references public.indicadores_riesgo(id) on delete cascade,
  id_estudiante int not null references public.estudiantes(id) on delete cascade,
  destinatario uuid not null references public.perfiles(id),
  tipo text not null check (tipo in ('estudiante','tutor')),
  nivel text not null,
  estado text not null default 'enviada' check (estado in ('enviada','leida','atendida')),
  fecha_envio timestamptz not null default now(),
  fecha_atencion timestamptz
);
create table public.tutorias (
  id serial primary key,
  id_estudiante int not null references public.estudiantes(id) on delete cascade,
  id_tutor uuid not null default auth.uid() references public.perfiles(id),
  fecha date not null check (fecha <= current_date),
  modalidad text not null check (modalidad in ('Presencial','Virtual')),
  acuerdos text not null check (char_length(acuerdos) between 20 and 1000),
  fecha_seguimiento date,
  creado timestamptz not null default now(),
  check (fecha_seguimiento is null or fecha_seguimiento > fecha)
);
create table public.tests_orientacion (
  id_estudiante int primary key references public.estudiantes(id) on delete cascade,
  respuestas jsonb not null default '{}',
  avance int not null default 0,
  completado boolean not null default false,
  resultado text,
  compartir boolean not null default false,
  actualizado timestamptz not null default now()
);
create table public.consentimientos (
  id serial primary key,
  id_usuario uuid not null references public.perfiles(id) on delete cascade,
  version text not null default '1.0',
  fecha_aceptacion timestamptz not null default now(),
  fecha_revocacion timestamptz
);
create table public.auditoria (
  id bigserial primary key,
  id_usuario uuid,
  correo text,
  accion text not null,
  recurso text,
  resultado text not null check (resultado in ('Permitido','Denegado')),
  fecha timestamptz not null default now()
);

-- ---------- funciones auxiliares ----------
create or replace function public.mi_rol() returns text
language sql stable security definer set search_path = public as
$$ select rol from public.perfiles where id = auth.uid() $$;

create or replace function public.mi_estudiante() returns int
language sql stable security definer set search_path = public as
$$ select id from public.estudiantes where id_usuario = auth.uid() $$;

create or replace function public.auditar(p_accion text, p_recurso text, p_resultado text) returns void
language sql security definer set search_path = public as
$$ insert into public.auditoria(id_usuario, correo, accion, recurso, resultado)
   values (auth.uid(), (select correo from public.perfiles where id = auth.uid()), p_accion, p_recurso, p_resultado) $$;

create or replace function public.consentimiento_activo(p_usuario uuid) returns boolean
language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.consentimientos where id_usuario = p_usuario and fecha_revocacion is null) $$;

create or replace function public.a_numero(t text) returns numeric
language plpgsql immutable as
$$ begin return t::numeric; exception when others then return null; end $$;

-- perfil automático para cada usuario nuevo (rol inicial: estudiante)
create or replace function public.crear_perfil() returns trigger
language plpgsql security definer set search_path = public as
$$ begin
  insert into public.perfiles(id, correo, nombres)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'nombres', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end $$;
create trigger trg_crear_perfil after insert on auth.users for each row execute function public.crear_perfil();

-- ---------- motor de riesgo (HU02) y alertas (HU03, HU04) ----------
create or replace function public.calcular_factores(p_est int) returns jsonb
language plpgsql stable security definer set search_path = public as
$$ declare r public.reglas_riesgo; v_asist numeric; v_prom numeric; v_desap int; v_inact int; v_per text;
begin
  select * into r from public.reglas_riesgo where id = 1;
  select max(periodo) into v_per from public.matriculas where id_estudiante = p_est;
  select coalesce(avg(asistencia), 100) into v_asist from public.matriculas where id_estudiante = p_est and periodo = v_per;
  select coalesce(avg(n.valor), 20), count(*) filter (where n.valor < 10.5) into v_prom, v_desap
    from public.notas n join public.matriculas m on m.id = n.id_matricula where m.id_estudiante = p_est and m.periodo = v_per;
  select coalesce(current_date - ultimo_acceso_aula, 0) into v_inact from public.estudiantes where id = p_est;
  return jsonb_build_object(
    'asistencia',   jsonb_build_object('valor', round(v_asist,1), 'umbral', r.umbral_asistencia,   'fuera', v_asist < r.umbral_asistencia,   'peso', r.peso_asistencia),
    'promedio',     jsonb_build_object('valor', round(v_prom,1),  'umbral', r.umbral_promedio,     'fuera', v_prom < r.umbral_promedio,      'peso', r.peso_promedio),
    'desaprobadas', jsonb_build_object('valor', v_desap,          'umbral', r.umbral_desaprobadas, 'fuera', v_desap >= r.umbral_desaprobadas, 'peso', r.peso_desaprobadas),
    'inactividad',  jsonb_build_object('valor', v_inact,          'umbral', r.umbral_inactividad,  'fuera', v_inact >= r.umbral_inactividad,  'peso', r.peso_inactividad));
end $$;

create or replace function public.recalcular_riesgo(p_carga int default null) returns int
language plpgsql security definer set search_path = public as
$$ declare e record; f jsonb; v_score int; v_nivel text; v_prev text; v_ind int; v_alertas int := 0;
begin
  for e in select * from public.estudiantes loop
    f := public.calcular_factores(e.id);
    select coalesce(sum((x.value->>'peso')::int) filter (where (x.value->>'fuera')::boolean), 0) into v_score from jsonb_each(f) x;
    v_nivel := case when v_score >= 60 then 'alto' when v_score >= 30 then 'medio' else 'bajo' end;
    select nivel into v_prev from public.indicadores_riesgo where id_estudiante = e.id order by fecha_calculo desc, id desc limit 1;
    insert into public.indicadores_riesgo(id_estudiante, id_carga, puntaje, nivel, factores) values (e.id, p_carga, v_score, v_nivel, f) returning id into v_ind;
    if v_nivel in ('medio','alto') and v_prev is distinct from v_nivel then
      -- alerta al estudiante: solo con consentimiento activo y sin repetir en el día (HU03)
      if e.id_usuario is not null and public.consentimiento_activo(e.id_usuario)
         and not exists (select 1 from public.alertas where id_estudiante = e.id and tipo = 'estudiante' and fecha_envio::date = current_date) then
        insert into public.alertas(id_indicador, id_estudiante, destinatario, tipo, nivel) values (v_ind, e.id, e.id_usuario, 'estudiante', v_nivel);
        v_alertas := v_alertas + 1;
      end if;
      -- aviso al tutor si pasa a riesgo alto y no hay un aviso abierto (HU04)
      if v_nivel = 'alto' and e.id_tutor is not null
         and not exists (select 1 from public.alertas where id_estudiante = e.id and tipo = 'tutor' and estado <> 'atendida') then
        insert into public.alertas(id_indicador, id_estudiante, destinatario, tipo, nivel) values (v_ind, e.id, e.id_tutor, 'tutor', v_nivel);
        v_alertas := v_alertas + 1;
      end if;
    end if;
  end loop;
  return v_alertas;
end $$;

-- ---------- vistas (respetan los permisos de quien consulta) ----------
create view public.v_riesgo_actual with (security_invoker = true) as
select e.id, e.codigo, e.nombres, c.nombre as carrera, e.ciclo,
       i.nivel, i.puntaje, i.factores, i.fecha_calculo,
       (i.factores->'asistencia'->>'valor')::numeric as asistencia,
       (i.factores->'promedio'->>'valor')::numeric as promedio,
       (select cu.nombre from public.matriculas m join public.cursos cu on cu.id = m.id_curso
         where m.id_estudiante = e.id order by m.asistencia asc limit 1) as curso_critico,
       (select array_agg(h.puntaje order by h.fecha_calculo, h.id) from
          (select puntaje, fecha_calculo, id from public.indicadores_riesgo where id_estudiante = e.id order by fecha_calculo desc, id desc limit 5) h) as historial
from public.estudiantes e
join public.carreras c on c.id = e.id_carrera
left join lateral (select * from public.indicadores_riesgo ir where ir.id_estudiante = e.id order by ir.fecha_calculo desc, ir.id desc limit 1) i on true;

create view public.v_avisos with (security_invoker = true) as
select a.id, a.id_estudiante, e.codigo, e.nombres, a.nivel, a.fecha_envio, a.fecha_atencion, a.destinatario,
       round(extract(epoch from (coalesce(a.fecha_atencion, now()) - a.fecha_envio)) / 3600)::int as horas,
       case when a.estado = 'atendida' then 'atendida'
            when now() - a.fecha_envio >= interval '72 hours' then 'escalada'
            else 'pendiente' end as estado
from public.alertas a join public.estudiantes e on e.id = a.id_estudiante
where a.tipo = 'tutor';

-- ---------- funciones que usa la aplicación (RPC) ----------
-- HU15: consentimiento
create or replace function public.aceptar_consentimiento() returns void
language plpgsql security definer set search_path = public as
$$ declare v_est int := public.mi_estudiante(); v_ind record;
begin
  if auth.uid() is null then raise exception 'NO_AUTENTICADO'; end if;
  if not public.consentimiento_activo(auth.uid()) then
    insert into public.consentimientos(id_usuario) values (auth.uid());
    perform public.auditar('Aceptar consentimiento', 'versión 1.0', 'Permitido');
  end if;
  -- si ya está en riesgo, recibe su alerta al aceptar (HU03)
  if v_est is not null then
    select * into v_ind from public.indicadores_riesgo where id_estudiante = v_est order by fecha_calculo desc, id desc limit 1;
    if v_ind.nivel in ('medio','alto') and not exists (select 1 from public.alertas where id_estudiante = v_est and tipo = 'estudiante' and fecha_envio::date = current_date) then
      insert into public.alertas(id_indicador, id_estudiante, destinatario, tipo, nivel) values (v_ind.id, v_est, auth.uid(), 'estudiante', v_ind.nivel);
    end if;
  end if;
end $$;

create or replace function public.revocar_consentimiento() returns void
language plpgsql security definer set search_path = public as
$$ begin
  update public.consentimientos set fecha_revocacion = now() where id_usuario = auth.uid() and fecha_revocacion is null;
  perform public.auditar('Revocar consentimiento', 'versión 1.0', 'Permitido');
end $$;

-- resumen de la app del estudiante (HU03, HU05, HU15)
create or replace function public.mi_resumen() returns jsonb
language plpgsql stable security definer set search_path = public as
$$ declare v_est int := public.mi_estudiante(); v_act boolean := public.consentimiento_activo(auth.uid()); r jsonb;
begin
  if v_est is null then return jsonb_build_object('estudiante', null); end if;
  select jsonb_build_object(
    'estudiante', (select jsonb_build_object('codigo', e.codigo, 'nombres', e.nombres, 'carrera', c.nombre, 'ciclo', e.ciclo)
                   from public.estudiantes e join public.carreras c on c.id = e.id_carrera where e.id = v_est),
    'consentimiento', jsonb_build_object('activo', v_act,
        'revocado', exists(select 1 from public.consentimientos where id_usuario = auth.uid() and fecha_revocacion is not null) and not v_act),
    'riesgo', case when v_act then (select jsonb_build_object('nivel', nivel, 'factores', factores, 'fecha', fecha_calculo)
                   from public.indicadores_riesgo where id_estudiante = v_est order by fecha_calculo desc, id desc limit 1) end,
    'alertas', case when v_act then coalesce((select jsonb_agg(jsonb_build_object('id', id, 'nivel', nivel, 'fecha', fecha_envio, 'leida', estado <> 'enviada') order by fecha_envio desc)
                   from public.alertas where destinatario = auth.uid() and tipo = 'estudiante'), '[]'::jsonb) else '[]'::jsonb end,
    'tutor', (select p.nombres from public.estudiantes e join public.perfiles p on p.id = e.id_tutor where e.id = v_est),
    'curso_critico', (select cu.nombre from public.matriculas m join public.cursos cu on cu.id = m.id_curso where m.id_estudiante = v_est order by m.asistencia limit 1),
    'test', (select to_jsonb(t) - 'id_estudiante' from public.tests_orientacion t where t.id_estudiante = v_est)
  ) into r;
  return r;
end $$;

create or replace function public.marcar_alerta_leida(p_id int) returns void
language sql security definer set search_path = public as
$$ update public.alertas set estado = 'leida' where id = p_id and destinatario = auth.uid() and estado = 'enviada' $$;

-- HU05: test de orientación (guardar y continuar)
create or replace function public.guardar_test(p_respuestas jsonb, p_avance int, p_completado boolean, p_resultado text, p_compartir boolean) returns void
language plpgsql security definer set search_path = public as
$$ declare v_est int := public.mi_estudiante();
begin
  if v_est is null then raise exception 'SOLO_ESTUDIANTES'; end if;
  if not public.consentimiento_activo(auth.uid()) then raise exception 'SIN_CONSENTIMIENTO'; end if;
  if p_avance < 0 or p_avance > 15 then raise exception 'AVANCE_INVALIDO'; end if;
  insert into public.tests_orientacion(id_estudiante, respuestas, avance, completado, resultado, compartir, actualizado)
  values (v_est, p_respuestas, p_avance, p_completado, p_resultado, p_compartir, now())
  on conflict (id_estudiante) do update set respuestas = excluded.respuestas, avance = excluded.avance,
    completado = excluded.completado, resultado = excluded.resultado, compartir = excluded.compartir, actualizado = now();
end $$;

-- HU02 + HU17: detalle del estudiante con control de acceso y auditoría
create or replace function public.ver_estudiante(p_id int) returns jsonb
language plpgsql security definer set search_path = public as
$$ declare v_rol text := public.mi_rol(); v_cod text; ok boolean; r jsonb;
begin
  select codigo into v_cod from public.estudiantes where id = p_id;
  ok := v_rol = 'coordinador' or (v_rol = 'tutor' and exists(select 1 from public.estudiantes where id = p_id and id_tutor = auth.uid()));
  if not ok then
    perform public.auditar('Ver detalle de estudiante', coalesce(v_cod, 'id ' || p_id), 'Denegado');
    return jsonb_build_object('denegado', true);
  end if;
  perform public.auditar('Ver detalle de estudiante', v_cod, 'Permitido');
  select jsonb_build_object(
    'estudiante', to_jsonb(v) - 'factores',
    'factores', v.factores,
    'tutorias', coalesce((select jsonb_agg(jsonb_build_object('fecha', t.fecha, 'modalidad', t.modalidad, 'acuerdos', t.acuerdos, 'seguimiento', t.fecha_seguimiento) order by t.fecha desc, t.id desc)
                 from public.tutorias t where t.id_estudiante = p_id), '[]'::jsonb),
    'test', (select jsonb_build_object('completado', t.completado, 'compartido', t.compartir, 'resultado', case when t.compartir then t.resultado end)
                 from public.tests_orientacion t where t.id_estudiante = p_id)
  ) into r from (select * from public.v_riesgo_actual where id = p_id) v;
  return r;
end $$;

create or replace function public.registrar_denegado(p_recurso text) returns void
language sql security definer set search_path = public as
$$ select public.auditar('Abrir ' || p_recurso, p_recurso, 'Denegado') $$;

-- HU04: atender aviso
create or replace function public.atender_alerta(p_id int) returns void
language plpgsql security definer set search_path = public as
$$ begin
  update public.alertas set estado = 'atendida', fecha_atencion = now()
   where id = p_id and tipo = 'tutor' and estado <> 'atendida' and (destinatario = auth.uid() or public.mi_rol() = 'coordinador');
  if not found then raise exception 'ALERTA_NO_DISPONIBLE'; end if;
end $$;

-- HU07: al registrar una tutoría se atienden los avisos abiertos de ese estudiante
create or replace function public.tutoria_atiende_avisos() returns trigger
language plpgsql security definer set search_path = public as
$$ begin
  update public.alertas set estado = 'atendida', fecha_atencion = now()
   where id_estudiante = new.id_estudiante and tipo = 'tutor' and estado <> 'atendida';
  return new;
end $$;
create trigger trg_tutoria_avisos after insert on public.tutorias for each row execute function public.tutoria_atiende_avisos();

-- HU02: reglas configurables (Coordinación de Bienestar)
create or replace function public.guardar_reglas(p_asist numeric, p_prom numeric, p_desap int, p_inact int,
  p_w_asist int, p_w_prom int, p_w_desap int, p_w_inact int) returns jsonb
language plpgsql security definer set search_path = public as
$$ declare v_antes int; v_despues int;
begin
  if public.mi_rol() is distinct from 'coordinador' then
    perform public.auditar('Modificar reglas del semáforo', 'reglas_riesgo', 'Denegado'); raise exception 'ACCESO_DENEGADO';
  end if;
  if p_asist not between 50 and 100 or p_prom not between 5 and 20 or p_desap not between 1 and 10 or p_inact not between 1 and 60 then raise exception 'UMBRAL_FUERA_DE_RANGO'; end if;
  if p_w_asist + p_w_prom + p_w_desap + p_w_inact <> 100 then raise exception 'PESOS_DEBEN_SUMAR_100'; end if;
  select count(*) into v_antes from public.v_riesgo_actual where nivel = 'alto';
  update public.reglas_riesgo set umbral_asistencia = p_asist, umbral_promedio = p_prom, umbral_desaprobadas = p_desap, umbral_inactividad = p_inact,
    peso_asistencia = p_w_asist, peso_promedio = p_w_prom, peso_desaprobadas = p_w_desap, peso_inactividad = p_w_inact, actualizado = now() where id = 1;
  perform public.recalcular_riesgo(null);
  select count(*) into v_despues from public.v_riesgo_actual where nivel = 'alto';
  perform public.auditar('Modificar reglas del semáforo', 'reglas_riesgo', 'Permitido');
  return jsonb_build_object('antes', v_antes, 'despues', v_despues);
end $$;

-- HU01: importación de datos académicos (todo o nada)
create or replace function public.importar_datos(p_filas jsonb, p_archivo text) returns jsonb
language plpgsql security definer set search_path = public as
$$ declare f jsonb; i int := 0; errs jsonb := '[]'::jsonb; vistos text[] := '{}'; k text;
  v_est int; v_cur int; v_mat int; v_nota numeric; v_asis numeric; v_carga int; v_alertas int;
begin
  if public.mi_rol() is distinct from 'ti' then
    perform public.auditar('Importar datos académicos', p_archivo, 'Denegado'); raise exception 'ACCESO_DENEGADO';
  end if;
  if jsonb_typeof(p_filas) <> 'array' or jsonb_array_length(p_filas) = 0 then raise exception 'ARCHIVO_VACIO'; end if;
  if jsonb_array_length(p_filas) > 20000 then raise exception 'ARCHIVO_DEMASIADO_GRANDE'; end if;
  -- 1) validar todas las filas
  for f in select value from jsonb_array_elements(p_filas) loop
    i := i + 1;
    k := upper(coalesce(f->>'codigo','')) || '|' || lower(coalesce(f->>'curso','')) || '|' || coalesce(f->>'periodo','') || '|' || upper(coalesce(f->>'evaluacion',''));
    v_nota := public.a_numero(f->>'nota'); v_asis := public.a_numero(f->>'asistencia');
    if coalesce(f->>'codigo','') !~ '^U[0-9]{9}$' then errs := errs || jsonb_build_object('fila', i+1, 'motivo', 'Código con formato inválido');
    elsif not exists(select 1 from public.estudiantes where codigo = f->>'codigo') then errs := errs || jsonb_build_object('fila', i+1, 'motivo', 'El código no corresponde a un estudiante registrado');
    elsif not exists(select 1 from public.cursos where lower(nombre) = lower(f->>'curso')) then errs := errs || jsonb_build_object('fila', i+1, 'motivo', 'Curso no registrado');
    elsif coalesce(f->>'periodo','') !~ '^[0-9]{4}-[12]$' then errs := errs || jsonb_build_object('fila', i+1, 'motivo', 'Periodo inválido (formato 2026-2)');
    elsif coalesce(trim(f->>'evaluacion'),'') = '' then errs := errs || jsonb_build_object('fila', i+1, 'motivo', 'Evaluación vacía');
    elsif v_nota is null or v_nota < 0 or v_nota > 20 then errs := errs || jsonb_build_object('fila', i+1, 'motivo', 'Nota fuera del rango 0–20');
    elsif v_asis is null or v_asis < 0 or v_asis > 100 then errs := errs || jsonb_build_object('fila', i+1, 'motivo', 'Asistencia fuera del rango 0–100');
    elsif k = any(vistos) then errs := errs || jsonb_build_object('fila', i+1, 'motivo', 'Registro duplicado en el archivo');
    else vistos := vistos || k;
    end if;
  end loop;
  if jsonb_array_length(errs) > 0 then
    insert into public.cargas_datos(id_usuario, correo, archivo, procesados, rechazados)
      values (auth.uid(), (select correo from public.perfiles where id = auth.uid()), p_archivo, 0, jsonb_array_length(errs));
    perform public.auditar('Importar datos académicos (rechazada)', p_archivo, 'Permitido');
    return jsonb_build_object('ok', false, 'errores', errs, 'rechazados', jsonb_array_length(errs));
  end if;
  -- 2) aplicar
  insert into public.cargas_datos(id_usuario, correo, archivo) values (auth.uid(), (select correo from public.perfiles where id = auth.uid()), p_archivo) returning id into v_carga;
  for f in select value from jsonb_array_elements(p_filas) loop
    select id into v_est from public.estudiantes where codigo = f->>'codigo';
    select id into v_cur from public.cursos where lower(nombre) = lower(f->>'curso');
    insert into public.matriculas(id_estudiante, id_curso, periodo, asistencia) values (v_est, v_cur, f->>'periodo', (f->>'asistencia')::numeric)
      on conflict (id_estudiante, id_curso, periodo) do update set asistencia = excluded.asistencia returning id into v_mat;
    insert into public.notas(id_matricula, evaluacion, valor) values (v_mat, upper(trim(f->>'evaluacion')), (f->>'nota')::numeric)
      on conflict (id_matricula, evaluacion) do update set valor = excluded.valor, fecha = now();
    if public.a_numero(f->>'dias_sin_acceso') is not null then
      update public.estudiantes set ultimo_acceso_aula = current_date - (f->>'dias_sin_acceso')::int where id = v_est;
    end if;
  end loop;
  update public.cargas_datos set procesados = jsonb_array_length(p_filas) where id = v_carga;
  v_alertas := public.recalcular_riesgo(v_carga);
  perform public.auditar('Importar datos académicos', p_archivo, 'Permitido');
  return jsonb_build_object('ok', true, 'procesados', jsonb_array_length(p_filas), 'rechazados', 0, 'alertas', v_alertas);
end $$;

-- ---------- seguridad por filas (HU17) ----------
alter table public.perfiles enable row level security;
alter table public.carreras enable row level security;
alter table public.cursos enable row level security;
alter table public.estudiantes enable row level security;
alter table public.matriculas enable row level security;
alter table public.notas enable row level security;
alter table public.cargas_datos enable row level security;
alter table public.reglas_riesgo enable row level security;
alter table public.indicadores_riesgo enable row level security;
alter table public.alertas enable row level security;
alter table public.tutorias enable row level security;
alter table public.tests_orientacion enable row level security;
alter table public.consentimientos enable row level security;
alter table public.auditoria enable row level security;

create policy perfil_propio on public.perfiles for select to authenticated using (id = auth.uid() or public.mi_rol() in ('coordinador','ti'));
create policy catalogo_carreras on public.carreras for select to authenticated using (true);
create policy catalogo_cursos on public.cursos for select to authenticated using (true);
create policy est_visibles on public.estudiantes for select to authenticated using (
  public.mi_rol() in ('coordinador','ti') or id_tutor = auth.uid() or id_usuario = auth.uid());
create policy mat_visibles on public.matriculas for select to authenticated using (
  exists(select 1 from public.estudiantes e where e.id = id_estudiante));
create policy notas_visibles on public.notas for select to authenticated using (
  exists(select 1 from public.matriculas m where m.id = id_matricula));
create policy ind_visibles on public.indicadores_riesgo for select to authenticated using (
  public.mi_rol() in ('coordinador','tutor') and exists(select 1 from public.estudiantes e where e.id = id_estudiante));
create policy alertas_visibles on public.alertas for select to authenticated using (destinatario = auth.uid() or public.mi_rol() = 'coordinador');
create policy tutorias_ver on public.tutorias for select to authenticated using (id_tutor = auth.uid() or public.mi_rol() = 'coordinador');
create policy tutorias_crear on public.tutorias for insert to authenticated with check (
  id_tutor = auth.uid() and public.mi_rol() = 'tutor' and exists(select 1 from public.estudiantes e where e.id = id_estudiante and e.id_tutor = auth.uid()));
create policy test_propio on public.tests_orientacion for select to authenticated using (id_estudiante = public.mi_estudiante());
create policy consent_propio on public.consentimientos for select to authenticated using (id_usuario = auth.uid() or public.mi_rol() = 'coordinador');
create policy reglas_ver on public.reglas_riesgo for select to authenticated using (true);
create policy cargas_ver on public.cargas_datos for select to authenticated using (public.mi_rol() in ('ti','coordinador'));
create policy auditoria_ver on public.auditoria for select to authenticated using (public.mi_rol() in ('ti','coordinador'));

-- permisos: nada para usuarios anónimos; lectura y RPC para usuarios autenticados
revoke all on all tables in schema public from anon;
revoke all on all functions in schema public from public, anon;
grant select on all tables in schema public to authenticated;
grant insert on public.tutorias to authenticated;
grant usage on all sequences in schema public to authenticated;
grant execute on function public.aceptar_consentimiento(), public.revocar_consentimiento(), public.mi_resumen(),
  public.marcar_alerta_leida(int), public.guardar_test(jsonb,int,boolean,text,boolean), public.ver_estudiante(int),
  public.registrar_denegado(text), public.atender_alerta(int), public.guardar_reglas(numeric,numeric,int,int,int,int,int,int),
  public.importar_datos(jsonb,text), public.mi_rol(), public.mi_estudiante(), public.consentimiento_activo(uuid) to authenticated;
-- funciones internas: no se exponen
revoke execute on function public.recalcular_riesgo(int), public.calcular_factores(int), public.auditar(text,text,text), public.crear_perfil(), public.tutoria_atiende_avisos() from authenticated;

-- ---------- datos de demostración (ficticios) ----------
insert into public.carreras(nombre) values ('Ing. de Sistemas'), ('Ing. Industrial');
insert into public.cursos(nombre, ciclo) values ('Matemática Básica',1), ('Comunicación',1), ('Fundamentos de Programación',1),
  ('Física I',2), ('Química General',1), ('Introducción a la Ingeniería',1);
insert into public.reglas_riesgo values (1, 75, 11, 2, 7, 35, 30, 20, 15, now());

do $$ declare
  nombres text[] := array['Lucía Ramos','Diego Huamán','Valeria Torres','Joaquín Paredes','Camila Rojas','Mateo Quispe','Ariana Salazar','Sebastián Lazo','Fernanda Ccori','Rodrigo Medina','Daniela Ponce','Gabriel Inga','Mariana Vega','Thiago Cárdenas','Ximena Arias','Bruno Espinoza','Antonella Ríos','Adrián Soto','Luana Mendoza','Iker Flores','Renata Chávez','Samuel Ortiz','Abril Castro','Leonardo Vargas','Micaela Núñez','Gael Palomino','Zoe Aquino','Emilio Benavides','Alessia Ruiz','Facundo Tello','Isabella Cruz','Matías Gamarra','Julieta Montes','Santiago Rivas','Kiara Lozano','Nicolás Yupanqui','Ainhoa Campos','Dylan Mamani','Ariadna León','Franco Villena','Estudiante de otro tutor'];
  i int; v_est int; v_mat int; c int; perfil int; base_as numeric; base_nt numeric; ev text;
begin
  perform setseed(0.42);
  for i in 1 .. array_length(nombres, 1) loop
    perfil := case when i = 1 then 3 when i = 41 then 0 else (i * 7) % 4 end;  -- 3 = alto, 2 = medio, 0-1 = bajo
    insert into public.estudiantes(codigo, nombres, id_carrera, ciclo, ultimo_acceso_aula)
    values (case when i = 41 then 'U202609911' else 'U2026' || lpad((1000 + (i-1) * 37)::text, 5, '0') end,
            nombres[i], 1 + (i % 2), 1 + (i % 2),
            current_date - case perfil when 3 then 8 + floor(random()*6)::int when 2 then 3 + floor(random()*6)::int else floor(random()*4)::int end)
    returning id into v_est;
    for c in 1 .. 3 loop
      base_as := case perfil when 3 then 58 + random()*14 when 2 then 68 + random()*14 else 82 + random()*17 end;
      insert into public.matriculas(id_estudiante, id_curso, periodo, asistencia)
      values (v_est, 1 + ((i + c * 2) % 6), '2026-2', round(base_as::numeric, 1)) on conflict do nothing returning id into v_mat;
      continue when v_mat is null;
      foreach ev in array array['PC1','PC2','PC3'] loop
        base_nt := case perfil when 3 then 6 + random()*6 when 2 then 9 + random()*5 else 12 + random()*7 end;
        insert into public.notas(id_matricula, evaluacion, valor) values (v_mat, ev, round(base_nt::numeric, 1));
      end loop;
    end loop;
  end loop;
  -- estudiante de la demo (Lucía Ramos): riesgo alto por asistencia, promedio y evaluaciones desaprobadas
  update public.estudiantes set ultimo_acceso_aula = current_date - 5 where codigo = 'U202601000';
  update public.matriculas set asistencia = 62 where id_estudiante = (select id from public.estudiantes where codigo = 'U202601000');
  update public.notas set valor = case when evaluacion in ('PC2','PC3') and id_matricula = (select min(m.id) from public.matriculas m join public.estudiantes e on e.id = m.id_estudiante where e.codigo = 'U202601000') then 9 else 10.8 end
   where id_matricula in (select m.id from public.matriculas m join public.estudiantes e on e.id = m.id_estudiante where e.codigo = 'U202601000');
end $$;
-- primer cálculo (sin tutores ni usuarios aún: no genera alertas)
select public.recalcular_riesgo(null);

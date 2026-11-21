-- =====================================================================
-- RUMBO_UC · PMV · Script 2 de 2: roles de los usuarios de demostración
-- Ejecutar DESPUÉS de crear los 4 usuarios en Authentication → Users → Add user
-- (marcar «Auto Confirm User»). Si usaron otros correos, cámbienlos aquí abajo.
-- =====================================================================
do $$ declare
  c_estudiante  text := 'estudiante@rumbo.test';
  c_tutora      text := 'tutora@rumbo.test';
  c_coordinador text := 'coordinacion@rumbo.test';
  c_ti          text := 'ti@rumbo.test';
  v_tutora uuid; v_est uuid; faltan text := '';
begin
  -- crea los perfiles si los usuarios existían antes del script 1
  insert into public.perfiles(id, correo, nombres)
    select id, email, split_part(email, '@', 1) from auth.users on conflict (id) do nothing;

  select id into v_est    from public.perfiles where lower(correo) = lower(c_estudiante);
  select id into v_tutora from public.perfiles where lower(correo) = lower(c_tutora);
  if v_est is null then faltan := faltan || ' ' || c_estudiante; end if;
  if v_tutora is null then faltan := faltan || ' ' || c_tutora; end if;
  if not exists(select 1 from public.perfiles where lower(correo) = lower(c_coordinador)) then faltan := faltan || ' ' || c_coordinador; end if;
  if not exists(select 1 from public.perfiles where lower(correo) = lower(c_ti)) then faltan := faltan || ' ' || c_ti; end if;
  if faltan <> '' then raise exception 'Primero creen estos usuarios en Authentication → Users:%', faltan; end if;

  update public.perfiles set rol = 'estudiante',  nombres = 'Lucía Ramos'          where id = v_est;
  update public.perfiles set rol = 'tutor',       nombres = 'Ing. Rosa Quispe'     where id = v_tutora;
  update public.perfiles set rol = 'coordinador', nombres = 'Lic. Martha Ccahuana' where lower(correo) = lower(c_coordinador);
  update public.perfiles set rol = 'ti',          nombres = 'Jorge Pariona'        where lower(correo) = lower(c_ti);

  -- la tutora tiene 40 tutorados; el estudiante U202609911 no es suyo (para probar HU17)
  update public.estudiantes set id_tutor = v_tutora where codigo <> 'U202609911';
  update public.estudiantes set id_usuario = null where id_usuario = v_est;
  update public.estudiantes set id_usuario = v_est where codigo = 'U202601000';

  -- reinicia el estado de la demo
  delete from public.alertas; delete from public.tutorias; delete from public.tests_orientacion;
  delete from public.consentimientos; delete from public.indicadores_riesgo; delete from public.auditoria;
  perform public.recalcular_riesgo(null);
  -- historial de dos cálculos anteriores para ver la tendencia en el dashboard
  insert into public.indicadores_riesgo(id_estudiante, puntaje, nivel, factores, fecha_calculo)
  select i.id_estudiante, g.p, case when g.p >= 60 then 'alto' when g.p >= 30 then 'medio' else 'bajo' end, i.factores, now() - (g.d || ' days')::interval
  from public.indicadores_riesgo i
  cross join lateral (values (14, greatest(0, i.puntaje - 30 + (i.id % 3) * 5)), (7, greatest(0, i.puntaje - 15 + (i.id % 2) * 5))) g(d, p);

  -- dos avisos «antiguos» para ver el escalamiento a las 72 h (HU04)
  update public.alertas set fecha_envio = now() - interval '80 hours'
   where id = (select a.id from public.alertas a join public.estudiantes e on e.id = a.id_estudiante where a.tipo = 'tutor' and e.codigo <> 'U202601000' order by a.id limit 1);
  update public.alertas set fecha_envio = now() - interval '50 hours'
   where id = (select a.id from public.alertas a join public.estudiantes e on e.id = a.id_estudiante where a.tipo = 'tutor' and e.codigo <> 'U202601000' order by a.id offset 1 limit 1);

  raise notice 'Listo: % estudiantes, % en riesgo alto, % avisos para la tutora.',
    (select count(*) from public.estudiantes), (select count(*) from public.v_riesgo_actual where nivel = 'alto'),
    (select count(*) from public.alertas where tipo = 'tutor');
end $$;

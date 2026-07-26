-- 과학 나선 교육과정 지도 · 방문자 카운트
-- Supabase 프로젝트에서 한 번만 실행하세요.
-- (여러 교사 앱에서 재사용 가능 — site 컬럼으로 앱을 구분합니다)

-- ─────────────────────────────────────────────
-- 1) 테이블: 앱마다 날짜별 방문 수
-- ─────────────────────────────────────────────
create table if not exists public.site_visits (
  site  text not null,                                          -- 앱 식별자 (예: 'science-curriculum-map')
  day   date not null,                                          -- 한국 시각 기준 날짜
  total bigint not null default 0,                              -- 그 날의 방문 수
  primary key (site, day)
);

-- 익명 브라우저는 테이블을 직접 못 읽고, 아래 함수만 쓸 수 있게 한다.
alter table public.site_visits enable row level security;

-- ─────────────────────────────────────────────
-- 2) 방문 카운트를 1 늘리고 오늘/누적을 돌려주는 함수
--    security definer 로 만들어야 익명 클라이언트가 함수 안에서만 테이블을 만질 수 있다.
-- ─────────────────────────────────────────────
create or replace function public.bump_visit(p_site text)
returns table(today bigint, total bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  today_kst date := (now() at time zone 'Asia/Seoul')::date;
  t_today bigint;
  t_total bigint;
begin
  insert into public.site_visits (site, day, total)
    values (p_site, today_kst, 1)
    on conflict (site, day)
    do update set total = public.site_visits.total + 1
    returning public.site_visits.total into t_today;
  select coalesce(sum(v.total), 0) into t_total
    from public.site_visits v where v.site = p_site;
  return query select t_today, t_total;
end;
$$;

-- 카운트 늘리지 않고 조회만 (같은 세션 재방문에서 씀)
create or replace function public.get_visits(p_site text)
returns table(today bigint, total bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  today_kst date := (now() at time zone 'Asia/Seoul')::date;
begin
  return query
    select
      coalesce((select v.total from public.site_visits v
                where v.site = p_site and v.day = today_kst), 0)::bigint,
      coalesce((select sum(v.total) from public.site_visits v
                where v.site = p_site), 0)::bigint;
end;
$$;

-- 익명 클라이언트에게 이 두 함수만 실행 권한 부여
grant execute on function public.bump_visit(text) to anon;
grant execute on function public.get_visits(text) to anon;

-- ─────────────────────────────────────────────
-- 확인용 (원하시면 실행)
-- ─────────────────────────────────────────────
-- select * from public.bump_visit('science-curriculum-map');
-- select * from public.get_visits('science-curriculum-map');
-- select * from public.site_visits order by day desc limit 10;

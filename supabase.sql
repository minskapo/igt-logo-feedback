-- 녹색전환연구소 로고 시안 의견수렴: Supabase SQL Editor에 붙여 넣고 Run 하세요.

create table if not exists public.feedback (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  section     text not null check (section in ('d01','d02','d03','d04','web','templates','pick')),
  rating      smallint check (rating between 1 and 5),
  choice      text check (choice in ('01','02','03','04')),
  comment     text check (char_length(comment) <= 2000),
  author      text check (char_length(author) <= 40),
  client_id   text not null check (char_length(client_id) between 8 and 64)
);

create index if not exists feedback_section_idx on public.feedback (section, created_at desc);

alter table public.feedback enable row level security;

-- 누구나 읽기·쓰기만 가능하고, 수정·삭제는 불가능합니다.
drop policy if exists "anyone can read"  on public.feedback;
drop policy if exists "anyone can write" on public.feedback;
create policy "anyone can read"  on public.feedback for select to anon, authenticated using (true);
create policy "anyone can write" on public.feedback for insert to anon, authenticated
  with check (rating is not null or choice is not null or (comment is not null and char_length(trim(comment)) > 0));

grant select, insert on public.feedback to anon, authenticated;

-- 같은 사람(브라우저)이 다시 매기면 마지막 점수·선택만 집계합니다.
create or replace view public.feedback_summary with (security_invoker = on) as
with latest_rating as (
  select distinct on (section, client_id) section, rating
  from public.feedback where rating is not null
  order by section, client_id, created_at desc
), latest_choice as (
  select distinct on (client_id) choice
  from public.feedback where section = 'pick' and choice is not null
  order by client_id, created_at desc
)
select section, null::text as choice, round(avg(rating)::numeric, 2) as avg_rating, count(*)::int as n
from latest_rating group by section
union all
select 'pick', choice, null, count(*)::int from latest_choice group by choice;

grant select on public.feedback_summary to anon, authenticated;

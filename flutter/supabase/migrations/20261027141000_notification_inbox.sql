-- Persist transactional purchase events separately from device push delivery.
-- There is deliberately no historical backfill or HTTP/push call.
create table public.notification_inbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  kind text not null check (kind in ('confirmed','ready','postponed')),
  title text not null,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index notification_inbox_user_created_idx
  on public.notification_inbox(user_id, created_at desc, id desc);
alter table public.notification_inbox enable row level security;
revoke all on public.notification_inbox from public, anon, authenticated;
grant select on public.notification_inbox to authenticated;
create policy notification_inbox_select_own on public.notification_inbox
  for select to authenticated using (user_id = (select auth.uid()));

create function public.mark_notification_read(p_notification_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  update public.notification_inbox set read_at = coalesce(read_at, now())
   where id = p_notification_id and user_id = v_uid;
  if not found then
    raise exception 'notification unavailable' using errcode = '42501';
  end if;
end $$;

create function public.mark_all_notifications_read()
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  update public.notification_inbox set read_at = now()
   where user_id = v_uid and read_at is null;
end $$;
revoke all on function public.mark_notification_read(uuid) from public, anon, authenticated;
revoke all on function public.mark_all_notifications_read() from public, anon, authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;

create function public.persist_purchase_notification()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_kind text; v_title text; v_body text; v_store text;
begin
  select name into v_store from public.stores where id = new.store_id;
  if tg_op = 'INSERT' then
    v_kind := 'confirmed';
    v_title := 'تم تأكيد الحجز';
    v_body := format('تم تأكيد حجزك لدى %s ليوم %s.', v_store, new.purchase_date);
  elsif new.purchase_date is distinct from old.purchase_date then
    v_kind := 'postponed';
    v_title := 'تم تأجيل الحجز';
    v_body := format('تم نقل حجزك لدى %s إلى يوم %s. افتح الحجز لعرض بياناته المحدثة.', v_store, new.purchase_date);
  elsif new.status = 'notified' and old.status is distinct from 'notified' then
    v_kind := 'ready';
    v_title := 'حان دورك للاستلام';
    v_body := format('حان دور حجزك لدى %s. افتح الحجز لعرض رمز الاستلام.', v_store);
  else
    return null;
  end if;
  insert into public.notification_inbox(user_id,purchase_id,kind,title,body)
    values (new.user_id,new.id,v_kind,v_title,v_body);
  return null;
end $$;
revoke all on function public.persist_purchase_notification() from public, anon, authenticated;
create trigger purchase_inbox_event
  after insert or update of status, purchase_date on public.purchases
  for each row execute function public.persist_purchase_notification();

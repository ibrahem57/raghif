-- A move retains the original purchase identity/payment and the global unique
-- (user_id,purchase_date) constraint. No second reservation/payment is inserted.
alter table public.purchases add column if not exists postponement_count int not null default 0 check (postponement_count between 0 and 1);
alter table public.purchases add column if not exists original_purchase_date date;

create or replace function public.postpone_purchase(p_purchase_id uuid)
returns public.purchases language plpgsql security definer set search_path=public as $$
declare
 v_uid uuid := auth.uid(); v_store_id uuid; v_store public.stores; v_p public.purchases;
 v_today date := (now() at time zone 'Asia/Hebron')::date; v_sold int; v_future int;
begin
 if v_uid is null then raise exception 'not authenticated'; end if;
 if not exists(select 1 from public.profiles where id=v_uid and role='buyer') then raise exception 'only buyers may postpone'; end if;
 select store_id into v_store_id from public.purchases where id=p_purchase_id and user_id=v_uid;
 if v_store_id is null then raise exception 'not your booking'; end if;
 -- Every queue RPC uses store-before-purchase locks. Recheck after the lock.
 select * into v_store from public.stores where id=v_store_id for update;
 select * into v_p from public.purchases where id=p_purchase_id and user_id=v_uid for update;
 if v_p.id is null then raise exception 'not your booking'; end if;
 if v_p.postponement_count > 0 then raise exception 'already postponed'; end if;
 if v_p.purchase_date <> v_today or v_p.status not in ('waiting','notified') then
  raise exception 'only today uncollected booking may be postponed'; end if;
 if exists(select 1 from public.purchases where user_id=v_uid and purchase_date=v_today+1) then
  raise exception 'already reserved a bag tomorrow'; end if;
 select count(*) into v_future from public.purchases where store_id=v_store_id and purchase_date=v_today+1;
 if v_future >= v_store.daily_bag_limit then raise exception 'tomorrow capacity exhausted'; end if;
 update public.purchases set purchase_date=v_today+1, original_purchase_date=v_today,
  postponement_count=1, status='waiting', batch_number=v_future/greatest(v_store.batch_size,1)+1
  where id=p_purchase_id returning * into v_p;
 select count(*) into v_sold from public.purchases where store_id=v_store_id and purchase_date=v_today;
 update public.stores set bags_remaining=greatest(least(bags_remaining+1,daily_bag_limit-v_sold),0) where id=v_store_id;
 return v_p;
exception when unique_violation then raise exception 'already reserved a bag tomorrow';
end $$;
revoke execute on function public.postpone_purchase(uuid) from public,anon;
grant execute on function public.postpone_purchase(uuid) to authenticated;

-- Ordinary reservations are for server-today only. Today's actual count also
-- includes yesterday's postponed orders; stale stock cannot exceed that bound.
create or replace function public.reserve_bag(p_store_id uuid,p_purchase_date date)
returns public.purchases language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_store public.stores; v_sold int; v_p public.purchases;
 v_today date := (now() at time zone 'Asia/Hebron')::date;
begin
 if v_uid is null then raise exception 'not authenticated'; end if;
 if p_purchase_date is distinct from v_today then raise exception 'reservations are for today only'; end if;
 select * into v_store from public.stores where id=p_store_id for update;
 select count(*) into v_sold from public.purchases where store_id=p_store_id and purchase_date=v_today;
 if v_store.id is null or not v_store.is_open or v_store.bags_remaining<=0 or v_sold>=v_store.daily_bag_limit then
  raise exception 'store closed or sold out'; end if;
 insert into public.purchases(store_id,user_id,purchase_date,batch_number,status)
 values(p_store_id,v_uid,v_today,v_sold/greatest(v_store.batch_size,1)+1,'waiting') returning * into v_p;
 update public.stores set bags_remaining=greatest(least(bags_remaining-1,daily_bag_limit-v_sold-1),0) where id=p_store_id;
 return v_p;
exception when unique_violation then raise exception 'already reserved a bag today';
end $$;

-- A lowered daily limit must still honor already accepted tomorrow capacity.
create or replace function public.save_store_allocation(p_store_id uuid,p_daily_bag_limit int,p_batch_size int,
 p_purchase_date date,p_open_time time default null,p_close_time time default null)
returns public.stores language plpgsql security definer set search_path=public as $$
declare v_sold int; v_future int; v_store public.stores; v_today date := (now() at time zone 'Asia/Hebron')::date;
begin
 select * into v_store from public.stores where id=p_store_id and owner_id=auth.uid() for update;
 if v_store.id is null then raise exception 'not the store owner'; end if;
 if p_purchase_date is distinct from v_today then raise exception 'allocation is for today only'; end if;
 select count(*) into v_future from public.purchases where store_id=p_store_id and purchase_date=v_today+1;
 if greatest(p_daily_bag_limit,0)<v_future then raise exception 'allocation below existing future bookings'; end if;
 select count(*) into v_sold from public.purchases where store_id=p_store_id and purchase_date=v_today;
 update public.stores set daily_bag_limit=greatest(p_daily_bag_limit,0),batch_size=greatest(p_batch_size,1),
  bags_remaining=greatest(p_daily_bag_limit-v_sold,0),open_time=p_open_time,close_time=p_close_time
 where id=p_store_id returning * into v_store;
 return v_store;
end $$;

create or replace function public.notify_next_batch(p_store_id uuid,p_purchase_date date)
returns setof public.purchases language plpgsql security definer set search_path=public as $$
declare v_next int;
begin
 perform 1 from public.stores where id=p_store_id and owner_id=auth.uid() for update;
 if not found then raise exception 'not the store owner'; end if;
 if p_purchase_date is distinct from (now() at time zone 'Asia/Hebron')::date then raise exception 'notify is for today only'; end if;
 select min(batch_number) into v_next from public.purchases where store_id=p_store_id and purchase_date=p_purchase_date and status='waiting';
 if v_next is null then raise exception 'no waiting batch to notify'; end if;
 return query update public.purchases set status='notified' where store_id=p_store_id and purchase_date=p_purchase_date and batch_number=v_next and status='waiting' returning *;
end $$;

create or replace function public.collect_purchase(p_purchase_id uuid)
returns public.purchases language plpgsql security definer set search_path=public as $$
declare v_p public.purchases; v_store_id uuid;
begin
 select store_id into v_store_id from public.purchases where id=p_purchase_id;
 perform 1 from public.stores where id=v_store_id and owner_id=auth.uid() for update;
 if not found then raise exception 'not the store owner'; end if;
 select * into v_p from public.purchases where id=p_purchase_id for update;
 if v_p.purchase_date <> (now() at time zone 'Asia/Hebron')::date then raise exception 'collection is for today only'; end if;
 if v_p.status='waiting' then raise exception 'batch not notified yet'; end if;
 update public.purchases set status='collected' where id=p_purchase_id returning * into v_p;
 return v_p;
end $$;

create or replace function public.record_scan(
  p_store_id uuid, p_outcome text, p_purchase_id uuid default null,
  p_scanned_name text default null, p_scanned_national_id text default null)
returns public.scan_events
language plpgsql security definer set search_path = public as $$
declare v_event public.scan_events;
begin
  if not exists (select 1 from public.stores where id = p_store_id and owner_id = (select auth.uid()))
  then raise exception 'not the store owner' using errcode = 'P0001'; end if;

  if p_outcome not in ('checkedIn', 'alreadyCollected', 'batchNotCalledYet',
                       'notFoundHere', 'wrongStore', 'invalidCode', 'staleReceipt') then
    raise exception 'unknown scan outcome' using errcode = 'P0001';
  end if;

  -- A scan of another store's receipt is still logged, but without linking
  -- this store's audit trail to a purchase it does not own.
  if p_purchase_id is not null and not exists (
    select 1 from public.purchases where id = p_purchase_id and store_id = p_store_id
  ) then p_purchase_id := null; end if;

  insert into public.scan_events (store_id, purchase_id, outcome, scanned_name, scanned_national_id)
  values (p_store_id, p_purchase_id, p_outcome, p_scanned_name, p_scanned_national_id)
  returning * into v_event;
  return v_event;
end; $$;

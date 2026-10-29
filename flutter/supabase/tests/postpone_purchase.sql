-- Transactional postponement regression suite. Run after all migrations; rolls back fixtures.
begin;
reset role;
create function pg_temp.postpone_as(uid uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', uid::text, true); execute 'set local role authenticated'; end $$;
create function pg_temp.postpone_fails(stmt text, needle text) returns void language plpgsql as $$
begin execute stmt; raise exception 'unexpected success';
exception when others then
 if sqlerrm = 'unexpected success' or position(needle in sqlerrm) = 0 then raise; end if;
end $$;
insert into auth.users(id) values
 ('90000000-0000-0000-0000-000000000001'), ('90000000-0000-0000-0000-000000000002'), ('90000000-0000-0000-0000-000000000003');
insert into public.profiles(id,phone,national_id,pin_hash,name,role) values
 ('90000000-0000-0000-0000-000000000001','p-owner','p-owner','x','Owner','owner'),
 ('90000000-0000-0000-0000-000000000002','p-buyer','p-buyer','x','Buyer','buyer'),
 ('90000000-0000-0000-0000-000000000003','p-other','p-other','x','Other','buyer');
insert into public.stores(id,name,owner_id,is_open,daily_bag_limit,bags_remaining,batch_size) values
 ('91000000-0000-0000-0000-000000000001','Postpone','90000000-0000-0000-0000-000000000001',true,2,2,1),
 ('91000000-0000-0000-0000-000000000002','Other bakery','90000000-0000-0000-0000-000000000001',true,2,2,1);
insert into public.purchases(id,user_id,store_id,purchase_date,batch_number,status) values
 ('92000000-0000-0000-0000-000000000001','90000000-0000-0000-0000-000000000002','91000000-0000-0000-0000-000000000001',(now() at time zone 'Asia/Hebron')::date,1,'notified');
select pg_temp.postpone_as('90000000-0000-0000-0000-000000000003');
select pg_temp.postpone_fails($q$select public.postpone_purchase('92000000-0000-0000-0000-000000000001')$q$,'not your booking');
select pg_temp.postpone_as('90000000-0000-0000-0000-000000000002');
select pg_temp.postpone_fails($q$select public.reserve_bag('91000000-0000-0000-0000-000000000001',(now() at time zone 'Asia/Hebron')::date+1)$q$,'today');
do $$ declare moved public.purchases; begin
 moved := public.postpone_purchase('92000000-0000-0000-0000-000000000001');
 if moved.purchase_date <> (now() at time zone 'Asia/Hebron')::date+1 or moved.status <> 'waiting' or moved.postponement_count <> 1
 then raise exception 'incorrect postponed booking %',row_to_json(moved); end if;
end $$;
select pg_temp.postpone_fails($q$select public.postpone_purchase('92000000-0000-0000-0000-000000000001')$q$,'already postponed');
select pg_temp.postpone_as('90000000-0000-0000-0000-000000000001');
select pg_temp.postpone_fails($q$select public.notify_next_batch('91000000-0000-0000-0000-000000000001',(now() at time zone 'Asia/Hebron')::date+1)$q$,'today');
select pg_temp.postpone_fails($q$select public.collect_purchase('92000000-0000-0000-0000-000000000001')$q$,'today');
select pg_temp.postpone_fails($q$select public.save_store_allocation('91000000-0000-0000-0000-000000000001',0,1,(now() at time zone 'Asia/Hebron')::date)$q$,'future bookings');
reset role;
-- Tomorrow's one bag quota includes a booking at any other bakery.
insert into public.purchases(id,user_id,store_id,purchase_date,batch_number) values
 ('92000000-0000-0000-0000-000000000002','90000000-0000-0000-0000-000000000003','91000000-0000-0000-0000-000000000001',(now() at time zone 'Asia/Hebron')::date,2),
 ('92000000-0000-0000-0000-000000000003','90000000-0000-0000-0000-000000000003','91000000-0000-0000-0000-000000000002',(now() at time zone 'Asia/Hebron')::date+1,1);
select pg_temp.postpone_as('90000000-0000-0000-0000-000000000003');
select pg_temp.postpone_fails($q$select public.postpone_purchase('92000000-0000-0000-0000-000000000002')$q$,'tomorrow');
reset role;
delete from public.purchases where id='92000000-0000-0000-0000-000000000003';
update public.stores set daily_bag_limit=1 where id='91000000-0000-0000-0000-000000000001';
select pg_temp.postpone_as('90000000-0000-0000-0000-000000000003');
select pg_temp.postpone_fails($q$select public.postpone_purchase('92000000-0000-0000-0000-000000000002')$q$,'capacity');
reset role;
do $$ begin
 if (select purchase_date from public.purchases where id='92000000-0000-0000-0000-000000000002') <> (now() at time zone 'Asia/Hebron')::date then raise exception 'failed move changed date'; end if;
end $$;
reset role;
update public.purchases set status='collected' where id='92000000-0000-0000-0000-000000000002';
select pg_temp.postpone_as('90000000-0000-0000-0000-000000000003');
select pg_temp.postpone_fails($q$select public.postpone_purchase('92000000-0000-0000-0000-000000000002')$q$,'uncollected');
reset role;
update public.purchases set status='waiting',purchase_date=(now() at time zone 'Asia/Hebron')::date-1 where id='92000000-0000-0000-0000-000000000002';
select pg_temp.postpone_as('90000000-0000-0000-0000-000000000003');
select pg_temp.postpone_fails($q$select public.postpone_purchase('92000000-0000-0000-0000-000000000002')$q$,'today');
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role anon;
select pg_temp.postpone_fails($q$select public.postpone_purchase('92000000-0000-0000-0000-000000000001')$q$,'permission denied');
rollback;

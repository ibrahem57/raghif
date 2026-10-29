-- Run against the local migration-test database with tests/stubs.sql only.
-- Rollback removes fixtures. net.http_post is the recording stub, never a push.
begin;
insert into auth.users (id) values
 ('22000000-0000-0000-0000-000000000001'),
 ('22000000-0000-0000-0000-000000000002');
insert into public.profiles (id,phone,national_id,pin_hash,name,role) values
 ('22000000-0000-0000-0000-000000000001','inbox1','inbox1','h','buyer1','buyer'),
 ('22000000-0000-0000-0000-000000000002','inbox2','inbox2','h','buyer2','buyer');
insert into public.stores (id,name,is_open,daily_bag_limit,bags_remaining)
 values ('22000000-0000-0000-0000-000000000003','inbox bakery',true,10,10);
insert into public.purchases (id,store_id,user_id,purchase_date,batch_number) values
 ('22000000-0000-0000-0000-000000000004','22000000-0000-0000-0000-000000000003','22000000-0000-0000-0000-000000000001',current_date,1),
 ('22000000-0000-0000-0000-000000000005','22000000-0000-0000-0000-000000000003','22000000-0000-0000-0000-000000000002',current_date,1);
update public.purchases set status='notified' where id='22000000-0000-0000-0000-000000000004';
-- An irrelevant update and repeated status never create duplicate ready messages.
update public.purchases set status='notified' where id='22000000-0000-0000-0000-000000000004';
update public.purchases set purchase_date=current_date+1,status='waiting' where id='22000000-0000-0000-0000-000000000004';
do $$ begin
 if (select count(*) from public.notification_inbox where user_id='22000000-0000-0000-0000-000000000001') <> 3
 then raise exception 'expected confirmed, ready, postponed only'; end if;
 if (select count(distinct kind) from public.notification_inbox where user_id='22000000-0000-0000-0000-000000000001') <> 3
 then raise exception 'missing event kind'; end if;
end $$;
create temp table foreign_notification as select id from public.notification_inbox where user_id='22000000-0000-0000-0000-000000000002';
grant select on foreign_notification to authenticated;
select set_config('request.jwt.claim.sub','22000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$ begin
 if (select count(*) from public.notification_inbox) <> 3 then raise exception 'cross-user inbox leak'; end if;
 if has_table_privilege(current_user,'public.notification_inbox','INSERT') or
    has_table_privilege(current_user,'public.notification_inbox','UPDATE') or
    has_table_privilege(current_user,'public.notification_inbox','DELETE')
 then raise exception 'clients have direct write privileges'; end if;
 begin
   perform public.mark_notification_read((select id from foreign_notification));
   raise exception 'foreign mark succeeded';
 exception when insufficient_privilege then null; end;
 perform public.mark_notification_read((select id from public.notification_inbox limit 1));
 perform public.mark_all_notifications_read();
 if exists(select 1 from public.notification_inbox where read_at is null) then raise exception 'own all-read failed'; end if;
end $$;
reset role;
do $$ begin
 if exists(select 1 from public.notification_inbox where user_id='22000000-0000-0000-0000-000000000002' and read_at is not null)
 then raise exception 'mark-all changed another user'; end if;
end $$;
set local role anon;
do $$ begin
 if has_table_privilege(current_user,'public.notification_inbox','SELECT') or
    has_function_privilege(current_user,'public.mark_all_notifications_read()','EXECUTE')
 then raise exception 'anonymous inbox privilege'; end if;
end $$;
reset role;
rollback;

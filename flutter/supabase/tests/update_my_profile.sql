-- Standalone, rollback-only profile RPC permissions and validation checks.
begin;
create function pg_temp.profile_must_fail(stmt text, needle text) returns void
language plpgsql as $$ begin
  execute stmt;
  raise exception 'unexpected success: %', stmt;
exception when others then
  if position(needle in sqlerrm) = 0 then raise; end if;
end $$;
insert into auth.users(id) values
 ('f0000000-0000-0000-0000-000000000001'),
 ('f0000000-0000-0000-0000-000000000002');
insert into public.profiles(id, name, phone, national_id, pin_hash, role, verification_status) values
 ('f0000000-0000-0000-0000-000000000001','First','0599888801','profile-test-1','secret','buyer','pending'),
 ('f0000000-0000-0000-0000-000000000002','Second','0599888802','profile-test-2','secret','buyer','pending');
set local role authenticated;
select set_config('request.jwt.claim.sub','f0000000-0000-0000-0000-000000000001',true);
select public.update_my_profile('  New name  ','0599888803','');
do $$ declare v jsonb; begin
  select to_jsonb(p) into v from public.update_my_profile('New name','0599888803','0599888804') p;
  if v ? 'pin_hash' then raise exception 'RPC leaked PIN hash'; end if;
  if v->>'id' <> 'f0000000-0000-0000-0000-000000000001' or v->>'phone' <> '0599888803'
    or v->>'national_id' <> 'profile-test-1' or v->>'role' <> 'buyer'
    or v->>'verification_status' <> 'pending' then raise exception 'invalid profile result'; end if;
end $$;
select pg_temp.profile_must_fail($q$select public.update_my_profile('','0599888803','')$q$, 'invalid profile');
select pg_temp.profile_must_fail($q$select public.update_my_profile('Name','123','')$q$, 'invalid profile');
select pg_temp.profile_must_fail($q$select public.update_my_profile('Name','0599888803','123')$q$, 'invalid profile');
select pg_temp.profile_must_fail($q$select public.update_my_profile('Name','0599888802','')$q$, 'phone already registered');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.profile_must_fail($q$select public.update_my_profile('Name','0599888803','')$q$, 'authentication required');
reset role;
do $$ begin
  if (select name <> 'Second' or phone <> '0599888802' from public.profiles where id='f0000000-0000-0000-0000-000000000002') then
    raise exception 'another profile changed';
  end if;
  if has_function_privilege('anon','public.update_my_profile(text,text,text)','EXECUTE') then
    raise exception 'anonymous execution allowed';
  end if;
end $$;
rollback;

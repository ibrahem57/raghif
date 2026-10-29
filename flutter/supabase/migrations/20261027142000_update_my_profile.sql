-- Synthetic auth email is derived from national_id, never phone; the
-- gateway reads profiles.phone for PIN login and OTP destination.
-- Only these editable fields may be supplied; identity and verification stay intact.
create or replace function public.update_my_profile(
  p_name text, p_phone text, p_jawwal_pay_number text
)
returns table (
  id uuid, phone text, national_id text, name text, role text,
  jawwal_pay_number text, verification_status text
)
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = 'P0001';
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 2 and 100
     or p_phone is null or btrim(p_phone) !~ '^05[69][0-9]{7}$'
     or (nullif(btrim(p_jawwal_pay_number), '') is not null
         and btrim(p_jawwal_pay_number) !~ '^05[69][0-9]{7}$') then
    raise exception 'invalid profile' using errcode = 'P0001';
  end if;

  update public.profiles p set name = btrim(p_name), phone = btrim(p_phone),
    jawwal_pay_number = nullif(btrim(p_jawwal_pay_number), '')
    where p.id = v_uid;
  if not found then raise exception 'profile not found' using errcode = 'P0001'; end if;
  return query select p.id, p.phone, p.national_id, p.name, p.role,
    p.jawwal_pay_number, p.verification_status from public.profiles p where p.id = v_uid;
exception when unique_violation then
  raise exception 'phone already registered' using errcode = 'P0001';
end;
$$;
revoke all on function public.update_my_profile(text,text,text) from public, anon;
grant execute on function public.update_my_profile(text,text,text) to authenticated;

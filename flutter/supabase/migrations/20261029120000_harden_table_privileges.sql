-- Supabase's default privileges hand anon/authenticated more than this app
-- uses: TRUNCATE, REFERENCES and TRIGGER on every public table. TRUNCATE is
-- the sharp edge — it is not subject to row level security — and none of the
-- three are needed by PostgREST or by any function here. RLS was the only
-- guard left on the older tables (profiles/stores/purchases); this closes the
-- gap without changing a single policy.
--
-- Anon keeps SELECT on stores (public store list) and nothing else: every
-- write policy on these tables requires auth.uid() = owner, which anon never
-- satisfies, so revoking the unused DML turns a silent 0-row write into an
-- honest permission error.
revoke truncate, references, trigger
  on public.profiles, public.stores, public.purchases,
     public.store_pins, public.scan_events, public.device_tokens
  from anon, authenticated;

revoke insert, update, delete
  on public.profiles, public.stores, public.purchases
  from anon;

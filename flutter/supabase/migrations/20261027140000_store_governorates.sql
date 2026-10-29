-- Nullable metadata; unclassified bakeries remain visible in browse-all.
alter table public.stores add column governorate text
  check (governorate in ('شمال غزة','غزة','الوسطى','خانيونس','رفح'));

update public.stores set governorate = case
  when area in ('جباليا','بيت لاهيا','بيت حانون') then 'شمال غزة'
  when area in ('الرمال','الزيتون','النصر','الشجاعية','الشاطئ','الساحة','الثلاثيني') then 'غزة'
  when area in ('دير البلح','النصيرات','البريج','المغازي','الزوايدة') then 'الوسطى'
  when area in ('خانيونس','القرارة','معن') then 'خانيونس'
  when area in ('حي السلام','الشابورة','تل السلطان') then 'رفح'
  else null end
where governorate is null;

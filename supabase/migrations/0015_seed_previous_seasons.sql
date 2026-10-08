-- Historical Hajj seasons, so the archive on the seasons screen has real rows
-- to show alongside whichever season is currently active.
--
-- `is_current` is left false for every row here: the partial unique index
-- `one_current_season` allows only one true, and the current season is owned by
-- the app (ensure_current_season / set_current_season). Seeding these as
-- not-current keeps this migration safe to run whatever the live state is.
--
-- gregorian_label follows the convention the app generates in
-- HijriUtils.currentGregorianLabel(): the Gregorian span the Hijri year falls
-- across, as "YYYY/YYYY+1". Dates bracket the Dhul-Hijjah pilgrimage period.
insert into seasons (hijri_year, gregorian_label, is_current, start_date, end_date) values
  (1443, '2021/2022', false, date '2022-07-05', date '2022-07-12'),
  (1444, '2022/2023', false, date '2023-06-24', date '2023-07-01'),
  (1445, '2023/2024', false, date '2024-06-12', date '2024-06-19'),
  (1446, '2024/2025', false, date '2025-06-02', date '2025-06-09'),
  (1447, '2025/2026', false, date '2026-05-23', date '2026-05-30')
on conflict (hijri_year) do nothing;

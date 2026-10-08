-- Baseline job titles (الأوصاف الوظيفية). Adjust freely from the admin UI later.
insert into job_titles (name) values
  ('رئيس البعثة'),
  ('نائب رئيس البعثة'),
  ('مدير إداري'),
  ('مشرف'),
  ('موظف إداري'),
  ('طبيب'),
  ('ممرض'),
  ('مرشد ديني'),
  ('مترجم'),
  ('سائق'),
  ('عامل خدمات')
on conflict do nothing;

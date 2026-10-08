-- عبدالله and عبد الله are the same man.
--
-- The Dart side learned this already: foldArabic() closes the space after a
-- standalone عبد, because whoever typed the man in on Tuesday put the space in
-- and whoever typed him in on Thursday did not. But every paged search — the
-- employee picker, the audit log, the task register — folds in THIS function,
-- and this function never learned it. So the picker answered "no results" to
-- عبدالله about a man filed as عبد الله, which is wrong about somebody who is
-- standing in the list.
--
-- The rule is the same as the Dart one, and must stay the same (the comment on
-- ar_fold says so in as many words): anchored to the start of a word so that
-- عابد الحسن keeps its space, and a trailing عبد with nothing after it —
-- "محمد عبد" — has no space to close and is left exactly as it is.
--
-- Applied AFTER the translate, not before: the tashkeel and tatweel that may
-- be sitting inside عَبْد are gone by then, so عَبْد ٱلله reaches the regexp
-- as عبد الله and closes like the rest.
create or replace function ar_fold(p text) returns text
  language sql immutable parallel safe as $$
  select regexp_replace(
    lower(
      translate(
        coalesce(p, ''),
        -- folded to the letter beneath them ...
        'أإآٱةىؤئ'
        -- ... Arabic-Indic digits to ASCII ...
        || '٠١٢٣٤٥٦٧٨٩'
        || '۰۱۲۳۴۵۶۷۸۹'
        -- ... and everything past here has no counterpart below, so it is
        -- dropped: tatweel, then tanween, harakat, shadda, sukun, the hamza
        -- and maddah marks, and the superscript alef.
        || chr(1600)
        || chr(1611) || chr(1612) || chr(1613) || chr(1614) || chr(1615)
        || chr(1616) || chr(1617) || chr(1618) || chr(1619) || chr(1620)
        || chr(1621) || chr(1648),
        'ااااهيوي'
        || '0123456789' || '0123456789'
      )
    ),
    -- a standalone عبد and the space after it, closed
    '(^|\s)عبد\s+', '\1عبد', 'g'
  );
$$;

comment on function ar_fold(text) is
  'The comparable form of an Arabic string: hamza seats folded onto their '
  'letters, taa marbuta to haa, alif maqsura to yaa, harakat and tatweel '
  'dropped, and the space inside a عبد- compound name closed. Mirrors '
  'foldArabic() in lib/core/utils/arabic_search.dart — the two must agree, or '
  'the directory and the picker will disagree about a name.';

-- =============================================
-- 05_patch_existing_db.sql
-- للمشاريع التي نفّذت 01..04 سابقاً على Supabase.
-- (التثبيت الجديد لا يحتاجه: التعديلات مدمجة في 03 و 04)
-- آمن للتشغيل أكثر من مرة.
-- =============================================

-- 1) تثبيت search_path للدوال (خصوصاً SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2) profiles: منع تغيير id عند التحديث
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
USING (id = (SELECT auth.uid()))
WITH CHECK (id = (SELECT auth.uid()));

-- 3) منع ربط طالب معلّم آخر بفصلك / حضورك / درجاتك
DROP POLICY IF EXISTS "Teachers manage enrollments of own classes" ON public.enrollments;
CREATE POLICY "Teachers manage enrollments of own classes"
ON public.enrollments FOR ALL
USING (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
)
WITH CHECK (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
  AND student_id IN (SELECT id FROM public.students WHERE teacher_id = (SELECT auth.uid()))
);

DROP POLICY IF EXISTS "Teachers manage records of own sessions" ON public.attendance_records;
CREATE POLICY "Teachers manage records of own sessions"
ON public.attendance_records FOR ALL
USING (
  session_id IN (
    SELECT s.id FROM public.attendance_sessions s
    JOIN public.classes c ON c.id = s.class_id
    WHERE c.teacher_id = (SELECT auth.uid())
  )
)
WITH CHECK (
  session_id IN (
    SELECT s.id FROM public.attendance_sessions s
    JOIN public.classes c ON c.id = s.class_id
    WHERE c.teacher_id = (SELECT auth.uid())
  )
  AND student_id IN (SELECT id FROM public.students WHERE teacher_id = (SELECT auth.uid()))
);

DROP POLICY IF EXISTS "Teachers manage grades of own assessments" ON public.grades;
CREATE POLICY "Teachers manage grades of own assessments"
ON public.grades FOR ALL
USING (
  assessment_id IN (
    SELECT a.id FROM public.assessments a
    JOIN public.classes c ON c.id = a.class_id
    WHERE c.teacher_id = (SELECT auth.uid())
  )
)
WITH CHECK (
  assessment_id IN (
    SELECT a.id FROM public.assessments a
    JOIN public.classes c ON c.id = a.class_id
    WHERE c.teacher_id = (SELECT auth.uid())
  )
  AND student_id IN (SELECT id FROM public.students WHERE teacher_id = (SELECT auth.uid()))
);

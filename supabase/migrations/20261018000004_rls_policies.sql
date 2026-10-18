-- تفعيل RLS والسياسات (آمن للإعادة، ويشمل إصلاحات الأمان)

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grade_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- profiles
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
ON public.profiles FOR SELECT
USING (id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
USING (id = (SELECT auth.uid()))
WITH CHECK (id = (SELECT auth.uid()));

-- classes
DROP POLICY IF EXISTS "Teachers manage own classes" ON public.classes;
CREATE POLICY "Teachers manage own classes"
ON public.classes FOR ALL
USING (teacher_id = (SELECT auth.uid()))
WITH CHECK (teacher_id = (SELECT auth.uid()));

-- students
DROP POLICY IF EXISTS "Teachers manage own students" ON public.students;
CREATE POLICY "Teachers manage own students"
ON public.students FOR ALL
USING (teacher_id = (SELECT auth.uid()))
WITH CHECK (teacher_id = (SELECT auth.uid()));

-- enrollments
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

-- attendance_sessions
DROP POLICY IF EXISTS "Teachers manage sessions of own classes" ON public.attendance_sessions;
CREATE POLICY "Teachers manage sessions of own classes"
ON public.attendance_sessions FOR ALL
USING (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
)
WITH CHECK (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
);

-- attendance_records
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

-- assessments
DROP POLICY IF EXISTS "Teachers manage assessments of own classes" ON public.assessments;
CREATE POLICY "Teachers manage assessments of own classes"
ON public.assessments FOR ALL
USING (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
)
WITH CHECK (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
);

-- grades
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

-- grade_settings
DROP POLICY IF EXISTS "Teachers manage grade settings of own classes" ON public.grade_settings;
CREATE POLICY "Teachers manage grade settings of own classes"
ON public.grade_settings FOR ALL
USING (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
)
WITH CHECK (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
);

-- audit_logs
DROP POLICY IF EXISTS "Teachers view own audit logs" ON public.audit_logs;
CREATE POLICY "Teachers view own audit logs"
ON public.audit_logs FOR SELECT
USING (teacher_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Teachers insert own audit logs" ON public.audit_logs;
CREATE POLICY "Teachers insert own audit logs"
ON public.audit_logs FOR INSERT
WITH CHECK (teacher_id = (SELECT auth.uid()));

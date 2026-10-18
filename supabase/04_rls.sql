-- =============================================
-- 04_rls.sql
-- تفعيل RLS + السياسات
-- =============================================

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
CREATE POLICY "Users can view own profile"
ON public.profiles FOR SELECT
USING (id = auth.uid());

CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
USING (id = auth.uid());

-- classes
CREATE POLICY "Teachers manage own classes"
ON public.classes FOR ALL
USING (teacher_id = auth.uid())
WITH CHECK (teacher_id = auth.uid());

-- students
CREATE POLICY "Teachers manage own students"
ON public.students FOR ALL
USING (teacher_id = auth.uid())
WITH CHECK (teacher_id = auth.uid());

-- enrollments
CREATE POLICY "Teachers manage enrollments of own classes"
ON public.enrollments FOR ALL
USING (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = auth.uid())
)
WITH CHECK (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = auth.uid())
);

-- attendance_sessions
CREATE POLICY "Teachers manage sessions of own classes"
ON public.attendance_sessions FOR ALL
USING (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = auth.uid())
)
WITH CHECK (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = auth.uid())
);

-- attendance_records
CREATE POLICY "Teachers manage records of own sessions"
ON public.attendance_records FOR ALL
USING (
  session_id IN (
    SELECT s.id FROM public.attendance_sessions s
    JOIN public.classes c ON c.id = s.class_id
    WHERE c.teacher_id = auth.uid()
  )
)
WITH CHECK (
  session_id IN (
    SELECT s.id FROM public.attendance_sessions s
    JOIN public.classes c ON c.id = s.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

-- assessments
CREATE POLICY "Teachers manage assessments of own classes"
ON public.assessments FOR ALL
USING (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = auth.uid())
)
WITH CHECK (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = auth.uid())
);

-- grades
CREATE POLICY "Teachers manage grades of own assessments"
ON public.grades FOR ALL
USING (
  assessment_id IN (
    SELECT a.id FROM public.assessments a
    JOIN public.classes c ON c.id = a.class_id
    WHERE c.teacher_id = auth.uid()
  )
)
WITH CHECK (
  assessment_id IN (
    SELECT a.id FROM public.assessments a
    JOIN public.classes c ON c.id = a.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

-- grade_settings
CREATE POLICY "Teachers manage grade settings of own classes"
ON public.grade_settings FOR ALL
USING (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = auth.uid())
)
WITH CHECK (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = auth.uid())
);

-- audit_logs
CREATE POLICY "Teachers view own audit logs"
ON public.audit_logs FOR SELECT
USING (teacher_id = auth.uid());

CREATE POLICY "Teachers insert own audit logs"
ON public.audit_logs FOR INSERT
WITH CHECK (teacher_id = auth.uid());

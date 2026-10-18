-- ==========================================
-- FILE: supabase/01_tables.sql
-- ==========================================
-- =============================================
-- 01_tables.sql
-- إنشاء كل الجداول بالترتيب الصحيح
-- =============================================

-- 1. profiles
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT '',
  email TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. classes
CREATE TABLE public.classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  subject TEXT,
  academic_year TEXT,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. students
CREATE TABLE public.students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  full_name TEXT NOT NULL,
  student_code TEXT,
  parent_phone TEXT,
  notes TEXT,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. enrollments
CREATE TABLE public.enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE RESTRICT,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE RESTRICT,
  enrollment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  left_date DATE,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_enrollment UNIQUE (class_id, student_id)
);

-- 5. attendance_sessions
CREATE TABLE public.attendance_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE RESTRICT,
  date DATE NOT NULL,
  period TEXT,
  notes TEXT,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. attendance_records
CREATE TABLE public.attendance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.attendance_sessions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE RESTRICT,
  status TEXT NOT NULL,
  notes TEXT,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_attendance_record UNIQUE (session_id, student_id),
  CONSTRAINT chk_status CHECK (status IN ('present', 'absent', 'late', 'excused'))
);

-- 7. assessments
CREATE TABLE public.assessments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  type TEXT,
  weight NUMERIC(5,2) NOT NULL DEFAULT 0,
  max_score NUMERIC(6,2) NOT NULL,
  date DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_weight_range CHECK (weight >= 0 AND weight <= 100),
  CONSTRAINT chk_max_score_positive CHECK (max_score > 0)
);

-- 8. grades
CREATE TABLE public.grades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID NOT NULL REFERENCES public.assessments(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE RESTRICT,
  raw_score NUMERIC(6,2),
  notes TEXT,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_grade UNIQUE (assessment_id, student_id)
);

-- 9. grade_settings
CREATE TABLE public.grade_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  grading_scale JSONB NOT NULL DEFAULT '[]'::jsonb,
  missing_grade_policy TEXT NOT NULL DEFAULT 'exclude',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_grade_settings_class UNIQUE (class_id),
  CONSTRAINT chk_missing_policy CHECK (missing_grade_policy IN ('exclude', 'zero'))
);

-- 10. audit_logs
CREATE TABLE public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  action TEXT NOT NULL,
  old_data JSONB,
  new_data JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================
-- FILE: supabase/02_indexes.sql
-- ==========================================
-- =============================================
-- 02_indexes.sql
-- =============================================

-- Partial Unique Indexes لحل مشكلة period = NULL
CREATE UNIQUE INDEX uq_daily_attendance
ON public.attendance_sessions (class_id, date)
WHERE period IS NULL AND deleted_at IS NULL;

CREATE UNIQUE INDEX uq_period_attendance
ON public.attendance_sessions (class_id, date, period)
WHERE period IS NOT NULL AND deleted_at IS NULL;

-- فهارس الأداء
CREATE INDEX idx_classes_teacher ON public.classes(teacher_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_students_teacher ON public.students(teacher_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_enrollments_class ON public.enrollments(class_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_enrollments_student ON public.enrollments(student_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_sessions_class_date ON public.attendance_sessions(class_id, date) WHERE deleted_at IS NULL;
CREATE INDEX idx_records_session ON public.attendance_records(session_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_records_student ON public.attendance_records(student_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_assessments_class ON public.assessments(class_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_grades_assessment ON public.grades(assessment_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_grades_student ON public.grades(student_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_audit_teacher ON public.audit_logs(teacher_id, created_at DESC);

-- ==========================================
-- FILE: supabase/03_triggers.sql
-- ==========================================
-- =============================================
-- 03_triggers.sql
-- =============================================

-- 1. دالة تحديث updated_at تلقائياً
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.classes
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.students
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.enrollments
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.attendance_sessions
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.attendance_records
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.assessments
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.grades
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.grade_settings
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 2. إنشاء profile تلقائياً عند تسجيل مستخدم جديد
-- SECURITY DEFINER بدون search_path ثابت ثغرة معروفة (search_path hijacking)
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

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==========================================
-- FILE: supabase/04_rls.sql
-- ==========================================
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
USING (id = (SELECT auth.uid()));

CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
USING (id = (SELECT auth.uid()))
WITH CHECK (id = (SELECT auth.uid()));

-- classes
CREATE POLICY "Teachers manage own classes"
ON public.classes FOR ALL
USING (teacher_id = (SELECT auth.uid()))
WITH CHECK (teacher_id = (SELECT auth.uid()));

-- students
CREATE POLICY "Teachers manage own students"
ON public.students FOR ALL
USING (teacher_id = (SELECT auth.uid()))
WITH CHECK (teacher_id = (SELECT auth.uid()));

-- enrollments
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
CREATE POLICY "Teachers manage sessions of own classes"
ON public.attendance_sessions FOR ALL
USING (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
)
WITH CHECK (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
);

-- attendance_records
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
CREATE POLICY "Teachers manage assessments of own classes"
ON public.assessments FOR ALL
USING (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
)
WITH CHECK (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
);

-- grades
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
CREATE POLICY "Teachers manage grade settings of own classes"
ON public.grade_settings FOR ALL
USING (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
)
WITH CHECK (
  class_id IN (SELECT id FROM public.classes WHERE teacher_id = (SELECT auth.uid()))
);

-- audit_logs
CREATE POLICY "Teachers view own audit logs"
ON public.audit_logs FOR SELECT
USING (teacher_id = (SELECT auth.uid()));

CREATE POLICY "Teachers insert own audit logs"
ON public.audit_logs FOR INSERT
WITH CHECK (teacher_id = (SELECT auth.uid()));

-- ==========================================
-- FILE: supabase/05_patch_existing_db.sql
-- ==========================================
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

-- ==========================================
-- FILE: supabase/06_sync_indexes.sql
-- ==========================================
-- =============================================
-- 06_sync_indexes.sql
-- فهارس تسرّع السحب التفاضلي (updated_at) للمزامنة. آمن للتشغيل أكثر من مرة.
-- =============================================
CREATE INDEX IF NOT EXISTS idx_sync_classes     ON public.classes(teacher_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_students    ON public.students(teacher_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_enrollments ON public.enrollments(updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_sessions    ON public.attendance_sessions(updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_records     ON public.attendance_records(updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_assessments ON public.assessments(updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_grades      ON public.grades(updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_settings    ON public.grade_settings(updated_at);


-- الفهارس + فهارس المزامنة (updated_at)

-- Partial Unique Indexes لحل مشكلة period = NULL
CREATE UNIQUE INDEX IF NOT EXISTS uq_daily_attendance
ON public.attendance_sessions (class_id, date)
WHERE period IS NULL AND deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_period_attendance
ON public.attendance_sessions (class_id, date, period)
WHERE period IS NOT NULL AND deleted_at IS NULL;

-- فهارس الأداء
CREATE INDEX IF NOT EXISTS idx_classes_teacher ON public.classes(teacher_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_students_teacher ON public.students(teacher_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_enrollments_class ON public.enrollments(class_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_enrollments_student ON public.enrollments(student_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_sessions_class_date ON public.attendance_sessions(class_id, date) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_records_session ON public.attendance_records(session_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_records_student ON public.attendance_records(student_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_assessments_class ON public.assessments(class_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_grades_assessment ON public.grades(assessment_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_grades_student ON public.grades(student_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_audit_teacher ON public.audit_logs(teacher_id, created_at DESC);

-- فهارس السحب التفاضلي للمزامنة
CREATE INDEX IF NOT EXISTS idx_sync_classes     ON public.classes(teacher_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_students    ON public.students(teacher_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_enrollments ON public.enrollments(updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_sessions    ON public.attendance_sessions(updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_records     ON public.attendance_records(updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_assessments ON public.assessments(updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_grades      ON public.grades(updated_at);
CREATE INDEX IF NOT EXISTS idx_sync_settings    ON public.grade_settings(updated_at);

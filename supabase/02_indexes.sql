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

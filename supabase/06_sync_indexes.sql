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

-- رقم الطالب فريد لكل معلم (بين الطلاب غير المحذوفين).
-- كان التحقق محلياً فقط، فجهازان يمكنهما إنشاء رقم مكرر.
-- آمن للتشغيل أكثر من مرة.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.students
    WHERE student_code IS NOT NULL AND deleted_at IS NULL
    GROUP BY teacher_id, student_code
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION
      'يوجد طلاب بأرقام مكررة عند نفس المعلم. عدّلها أو احذفها ثم أعد التشغيل. للكشف عنها: SELECT teacher_id, student_code, COUNT(*) FROM public.students WHERE student_code IS NOT NULL AND deleted_at IS NULL GROUP BY 1, 2 HAVING COUNT(*) > 1;';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_students_teacher_code
ON public.students (teacher_id, student_code)
WHERE student_code IS NOT NULL AND deleted_at IS NULL;

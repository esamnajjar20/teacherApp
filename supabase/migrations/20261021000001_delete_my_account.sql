-- =============================================
-- delete_my_account()
-- حذف نهائي لحساب المستخدم الحالي وكل بياناته.
-- آمن للاستخدام من التطبيق عبر: supabase.rpc('delete_my_account')
-- =============================================

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'غير مصرح: يجب تسجيل الدخول أولاً';
  END IF;

  -- الحذف بالترتيب: الأبناء قبل الآباء
  DELETE FROM public.audit_logs WHERE teacher_id = v_uid;

  DELETE FROM public.grades WHERE assessment_id IN (
    SELECT a.id FROM public.assessments a
    JOIN public.classes c ON c.id = a.class_id
    WHERE c.teacher_id = v_uid
  );

  DELETE FROM public.attendance_records WHERE session_id IN (
    SELECT s.id FROM public.attendance_sessions s
    JOIN public.classes c ON c.id = s.class_id
    WHERE c.teacher_id = v_uid
  );

  DELETE FROM public.attendance_sessions WHERE class_id IN (
    SELECT id FROM public.classes WHERE teacher_id = v_uid
  );

  DELETE FROM public.assessments WHERE class_id IN (
    SELECT id FROM public.classes WHERE teacher_id = v_uid
  );

  DELETE FROM public.grade_settings WHERE class_id IN (
    SELECT id FROM public.classes WHERE teacher_id = v_uid
  );

  DELETE FROM public.enrollments WHERE class_id IN (
    SELECT id FROM public.classes WHERE teacher_id = v_uid
  );

  DELETE FROM public.classes WHERE teacher_id = v_uid;
  DELETE FROM public.students WHERE teacher_id = v_uid;
  DELETE FROM public.profiles WHERE id = v_uid;

  -- حذف المستخدم من auth.users (يعمل بفضل SECURITY DEFINER)
  DELETE FROM auth.users WHERE id = v_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

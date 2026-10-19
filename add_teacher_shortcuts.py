import os
import shutil
import re

print("=" * 72)
print("🚀 إضافة ميزات تسهيل المعلم (7 ميزات)")
print("=" * 72)

# ============================================================
# [1/2] take_attendance_screen.dart
# ============================================================
print("\n📁 [1/2] شاشة الحضور")

path = 'lib/features/attendance/presentation/screens/take_attendance_screen.dart'

if not os.path.exists(path):
    print(f"   ❌ غير موجود: {path}")
else:
    shutil.copy(path, path + '.bak')
    print(f"   💾 نسخة احتياطية")

    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    original = c

    # 1.1: إضافة search state
    old_state = '''  /// هل هناك تعديلات لم تُحفظ بعد؟
  bool _dirty = false;'''
    new_state = '''  /// هل هناك تعديلات لم تُحفظ بعد؟
  bool _dirty = false;

  /// نص البحث في قائمة الطلاب
  final _searchCtrl = TextEditingController();
  String _search = '';

  /// الطلاب الغائبون في آخر جلسة (للإشارة)
  Set<String> _absentLastSession = {};'''

    if old_state in c:
        c = c.replace(old_state, new_state, 1)
        print("   ✅ إضافة state البحث")

    # 1.2: dispose البحث
    old_dispose = '''  Future<void> _pickDate() async {'''
    new_dispose = '''  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// نسخ حضور آخر جلسة على هذا التاريخ
  Future<void> _copyLastSession() async {
    try {
      final sessions = await _db.getSessionsForClass(widget.classModel.id);
      // استبعاد الجلسة الحالية (إن وُجدت)
      final currentSession = await _db.findSession(
        classId: widget.classModel.id,
        date: _selectedDate,
      );
      final previous = sessions.where((s) => s.id != currentSession?.id).toList();

      if (previous.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد جلسة سابقة لنسخها'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final lastSession = previous.first;
      final records = await _db.getRecordsForSession(lastSession.id);

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('نسخ من آخر جلسة'),
          content: Text(
            'سيُنسخ حضور جلسة ${lastSession.date.year}/'
            '${lastSession.date.month.toString().padLeft(2, '0')}/'
            '${lastSession.date.day.toString().padLeft(2, '0')} '
            '(${records.length} سجل).\n\n'
            'ستُستبدل الحالات الحالية. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نسخ'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      setState(() {
        _resetToDefault();
        for (final r in records) {
          if (_statusMap.containsKey(r.studentId)) {
            _statusMap[r.studentId] = r.status;
          }
        }
        _dirty = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ الحضور — راجع ثم اضغط حفظ'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    }
  }

  /// تحميل الغائبين من آخر جلسة (لإظهار شارة بجانب الطالب)
  Future<void> _loadAbsentLastSession() async {
    try {
      final sessions = await _db.getSessionsForClass(widget.classModel.id);
      if (sessions.isEmpty) return;

      final currentSession = await _db.findSession(
        classId: widget.classModel.id,
        date: _selectedDate,
      );
      final previous = sessions.where((s) => s.id != currentSession?.id).toList();
      if (previous.isEmpty) return;

      final records = await _db.getRecordsForSession(previous.first.id);
      if (!mounted) return;
      setState(() {
        _absentLastSession = records
            .where((r) => r.status == AppConstants.absent)
            .map((r) => r.studentId)
            .toSet();
      });
    } catch (_) {}
  }

  Future<void> _pickDate() async {'''

    if old_dispose in c and '_copyLastSession' not in c:
        c = c.replace(old_dispose, new_dispose, 1)
        print("   ✅ إضافة _copyLastSession + _loadAbsentLastSession + dispose")

    # 1.3: استدعاء _loadAbsentLastSession في initState
    old_init = '''    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadExisting();
    });'''
    new_init = '''    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadExisting();
      if (mounted) _loadAbsentLastSession();
    });'''

    if old_init in c and '_loadAbsentLastSession()' not in c:
        c = c.replace(old_init, new_init, 1)
        print("   ✅ تحميل الغائبين في initState")

    # 1.4: إضافة زر قائمة في AppBar + "الكل متأخر"
    old_appbar = '''          actions: [
            TextButton(
              onPressed: (_isSaving || _isLoadingExisting) ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],'''
    new_appbar = '''          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'copy') _copyLastSession();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy_all_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('نسخ من آخر جلسة'),
                    ],
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: (_isSaving || _isLoadingExisting) ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],'''

    if old_appbar in c:
        c = c.replace(old_appbar, new_appbar, 1)
        print("   ✅ قائمة AppBar (نسخ من آخر جلسة)")

    # 1.5: إضافة "الكل متأخر" + البحث
    old_setall = '''                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: widget.students.isEmpty
                            ? null
                            : () => _setAll(AppConstants.present),
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.green, size: 18),
                        label: const Text('الكل حاضر'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: widget.students.isEmpty
                            ? null
                            : () => _setAll(AppConstants.absent),
                        icon: const Icon(Icons.cancel_outlined,
                            color: Colors.red, size: 18),
                        label: const Text('الكل غائب'),
                      ),
                    ],
                  ),'''

    new_setall = '''                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: widget.students.isEmpty
                            ? null
                            : () => _setAll(AppConstants.present),
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.green, size: 18),
                        label: const Text('الكل حاضر'),
                      ),
                      TextButton.icon(
                        onPressed: widget.students.isEmpty
                            ? null
                            : () => _setAll(AppConstants.absent),
                        icon: const Icon(Icons.cancel_outlined,
                            color: Colors.red, size: 18),
                        label: const Text('الكل غائب'),
                      ),
                      TextButton.icon(
                        onPressed: widget.students.isEmpty
                            ? null
                            : () => _setAll(AppConstants.late),
                        icon: const Icon(Icons.access_time,
                            color: Colors.orange, size: 18),
                        label: const Text('الكل متأخر'),
                      ),
                    ],
                  ),'''

    if old_setall in c:
        c = c.replace(old_setall, new_setall, 1)
        print("   ✅ زر \"الكل متأخر\"")

    # 1.6: إضافة البحث + فلترة الطلاب
    old_list = '''            if (_isLoadingExisting) const LinearProgressIndicator(minHeight: 2),
            // قائمة الطلاب
            Expanded(
              child: widget.students.isEmpty
                  ? const Center(child: Text('لا يوجد طلاب في الفصل'))
                  : ListView.builder(
                      itemCount: widget.students.length,
                      itemBuilder: (context, index) {
                        final student = widget.students[index];
                        final status = _statusMap[student.id] ?? AppConstants.present;'''

    new_list = '''            if (_isLoadingExisting) const LinearProgressIndicator(minHeight: 2),
            // حقل البحث
            if (widget.students.length > 5)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'ابحث باسم الطالب...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
            // قائمة الطلاب
            Expanded(
              child: widget.students.isEmpty
                  ? const Center(child: Text('لا يوجد طلاب في الفصل'))
                  : Builder(
                      builder: (context) {
                        final filtered = _search.isEmpty
                            ? widget.students
                            : widget.students
                                .where((s) => s.fullName
                                    .toLowerCase()
                                    .contains(_search.toLowerCase()))
                                .toList();
                        if (filtered.isEmpty) {
                          return const Center(
                              child: Text('لا توجد نتائج مطابقة'));
                        }
                        return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final student = filtered[index];
                        final status = _statusMap[student.id] ?? AppConstants.present;
                        final wasAbsent = _absentLastSession.contains(student.id);'''

    if old_list in c:
        c = c.replace(old_list, new_list, 1)
        print("   ✅ بحث + فلترة الطلاب")

    # 1.7: إضافة شارة "غائب أمس" + إغلاق الـ Builder
    old_tile = '''                          trailing: Icon(
                            Icons.touch_app,
                            color: Colors.grey[400],
                          ),
                          onTap: () => _cycleStatus(student.id),
                          onLongPress: () => _pickStatus(student),
                        );
                      },
                    ),
            ),'''

    new_tile = '''                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (wasAbsent)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'غاب سابقاً',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.red),
                                  ),
                                ),
                              Icon(
                                Icons.touch_app,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                          onTap: () => _cycleStatus(student.id),
                          onLongPress: () => _pickStatus(student),
                        );
                      },
                    );
                      },
                    ),
            ),'''

    if old_tile in c:
        c = c.replace(old_tile, new_tile, 1)
        print("   ✅ شارة \"غاب سابقاً\"")

    if c != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(c)
        print(f"   💾 حفظ ({len(c)} حرف)")

# ============================================================
# [2/2] enter_grades_screen.dart
# ============================================================
print("\n📁 [2/2] شاشة إدخال الدرجات")

path = 'lib/features/grades/presentation/screens/enter_grades_screen.dart'

if not os.path.exists(path):
    print(f"   ❌ غير موجود: {path}")
else:
    shutil.copy(path, path + '.bak')
    print(f"   💾 نسخة احتياطية")

    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    original = c

    # 2.1: إضافة state البحث
    old_state = '''  bool _isLoading = true;
  bool _isSaving = false;
  bool _dirty = false;'''
    new_state = '''  bool _isLoading = true;
  bool _isSaving = false;
  bool _dirty = false;

  /// نص البحث
  final _searchCtrl = TextEditingController();
  String _search = '';'''

    if old_state in c:
        c = c.replace(old_state, new_state, 1)
        print("   ✅ إضافة state البحث")

    # 2.2: dispose + طرق الملء والمسح
    old_dispose = '''  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }'''
    new_dispose = '''  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// ملء درجة الجميع بالدرجة العظمى
  void _fillAllMax() {
    final max = widget.assessment.maxScore;
    final display = formatNumber(max);
    for (final ctrl in _controllers.values) {
      ctrl.text = display;
    }
    setState(() => _dirty = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم ملء جميع الدرجات بـ $display')),
    );
  }

  /// مسح جميع الحقول
  void _clearAll() {
    for (final ctrl in _controllers.values) {
      ctrl.clear();
    }
    setState(() => _dirty = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم مسح جميع الدرجات')),
    );
  }

  /// تعيين "بدون درجة" للجميع (فراغ)
  void _setAllNoGrade() {
    _clearAll();
  }'''

    if old_dispose in c and '_fillAllMax' not in c:
        c = c.replace(old_dispose, new_dispose, 1)
        print("   ✅ إضافة _fillAllMax + _clearAll + _setAllNoGrade + dispose")

    # 2.3: إضافة قائمة في AppBar
    old_appbar = '''      appBar: AppBar(
        title: Text(widget.assessment.name),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),'''

    new_appbar = '''      appBar: AppBar(
        title: Text(widget.assessment.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'fill_max') _fillAllMax();
              if (value == 'clear') _clearAll();
              if (value == 'no_grade') _setAllNoGrade();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'fill_max',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 20, color: Colors.green),
                    SizedBox(width: 8),
                    Text('ملء الدرجة العظمى للكل'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('مسح جميع الدرجات'),
                  ],
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),'''

    if old_appbar in c:
        c = c.replace(old_appbar, new_appbar, 1)
        print("   ✅ قائمة AppBar (ملء/مسح)")

    # 2.4: البحث + النسبة + فلترة
    old_list = '''                Expanded(
                  child: widget.students.isEmpty
                      ? const Center(child: Text('لا يوجد طلاب'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: widget.students.length,
                          itemBuilder: (context, index) {
                            final student = widget.students[index];
                            final ctrl = _controllers[student.id]!;'''

    new_list = '''                if (widget.students.length > 5)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'ابحث باسم الطالب...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                              ),
                      ),
                      onChanged: (v) => setState(() => _search = v.trim()),
                    ),
                  ),
                Expanded(
                  child: widget.students.isEmpty
                      ? const Center(child: Text('لا يوجد طلاب'))
                      : Builder(
                          builder: (context) {
                            final filtered = _search.isEmpty
                                ? widget.students
                                : widget.students
                                    .where((s) => s.fullName
                                        .toLowerCase()
                                        .contains(_search.toLowerCase()))
                                    .toList();
                            if (filtered.isEmpty) {
                              return const Center(
                                  child: Text('لا توجد نتائج مطابقة'));
                            }
                            return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final student = filtered[index];
                            final ctrl = _controllers[student.id]!;'''

    if old_list in c:
        c = c.replace(old_list, new_list, 1)
        print("   ✅ بحث + فلترة")

    # 2.5: النسبة بجانب كل طالب + إغلاق Builder
    old_input = '''                                    SizedBox(
                                      width: 90,
                                      child: TextField(
                                        controller: ctrl,
                                        textInputAction: index == widget.students.length - 1
                                            ? TextInputAction.done
                                            : TextInputAction.next,
                                        onChanged: (_) {
                                          if (!_dirty) setState(() => _dirty = true);
                                        },
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          hintText: '0-${formatNumber(widget.assessment.maxScore)}',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 10,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),'''

    new_input = '''                                    SizedBox(
                                      width: 90,
                                      child: ValueListenableBuilder<TextEditingValue>(
                                        valueListenable: ctrl,
                                        builder: (_, val, __) {
                                          final score = parseNumber(val.text);
                                          final pct = (score != null &&
                                                  score >= 0 &&
                                                  widget.assessment.maxScore > 0)
                                              ? (score /
                                                      widget.assessment.maxScore *
                                                      100)
                                                  .toStringAsFixed(0)
                                              : null;
                                          return TextField(
                                            controller: ctrl,
                                            textInputAction: index ==
                                                    filtered.length - 1
                                                ? TextInputAction.done
                                                : TextInputAction.next,
                                            onChanged: (_) {
                                              if (!_dirty) {
                                                setState(() => _dirty = true);
                                              }
                                            },
                                            keyboardType: const TextInputType
                                                .numberWithOptions(decimal: true),
                                            textAlign: TextAlign.center,
                                            decoration: InputDecoration(
                                              hintText:
                                                  '0-${formatNumber(widget.assessment.maxScore)}',
                                              suffixText: pct != null ? '$pct%' : null,
                                              suffixStyle: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.blue),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 10,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                          },
                        ),
                ),'''

    if old_input in c:
        c = c.replace(old_input, new_input, 1)
        print("   ✅ النسبة % بجانب كل درجة")

    if c != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(c)
        print(f"   💾 حفظ ({len(c)} حرف)")

# ============================================================
# التحقق
# ============================================================
print("\n" + "=" * 72)
print("🔍 التحقق")
print("=" * 72)

checks = [
    ('lib/features/attendance/presentation/screens/take_attendance_screen.dart', {
        'بحث في الحضور': '_searchCtrl' in open('lib/features/attendance/presentation/screens/take_attendance_screen.dart').read(),
        'نسخ من آخر جلسة': '_copyLastSession' in open('lib/features/attendance/presentation/screens/take_attendance_screen.dart').read(),
        'الكل متأخر': 'الكل متأخر' in open('lib/features/attendance/presentation/screens/take_attendance_screen.dart').read(),
        'غاب سابقاً': 'غاب سابقاً' in open('lib/features/attendance/presentation/screens/take_attendance_screen.dart').read(),
    }),
    ('lib/features/grades/presentation/screens/enter_grades_screen.dart', {
        'بحث في الدرجات': '_searchCtrl' in open('lib/features/grades/presentation/screens/enter_grades_screen.dart').read(),
        'ملء بالدرجة العظمى': '_fillAllMax' in open('lib/features/grades/presentation/screens/enter_grades_screen.dart').read(),
        'مسح الكل': '_clearAll' in open('lib/features/grades/presentation/screens/enter_grades_screen.dart').read(),
        'النسبة %': 'ValueListenableBuilder<TextEditingValue>' in open('lib/features/grades/presentation/screens/enter_grades_screen.dart').read(),
    }),
]

all_ok = True
for path, checks_dict in checks:
    name = os.path.basename(path)
    if not os.path.exists(path):
        print(f"   ❌ {name}")
        all_ok = False
        continue
    file_ok = True
    for label, ok in checks_dict.items():
        if not ok:
            print(f"   ⚠️  {name}: {label}")
            file_ok = False
            all_ok = False
    if file_ok:
        print(f"   ✅ {name}")

print("\n" + "=" * 72)
if all_ok:
    print("🎉 جميع الميزات مطبقة!")
else:
    print("⚠️  بعض الميزات فشلت")
print("=" * 72)
print("""
🚀 الخطوات:

  rm -f add_teacher_shortcuts.py
  git add .
  git commit -m "Feat: Teacher shortcuts (search, copy session, fill max, percentage)"
  git push origin main
  
  sleep 5
  gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
""")

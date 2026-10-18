import 'package:flutter/material.dart';
import '../../../../shared/models/class_model.dart';
import '../../../../shared/services/database_service.dart';
import '../../../students/presentation/screens/class_detail_screen.dart';

class GradesListScreen extends StatefulWidget {
  const GradesListScreen({super.key});

  @override
  State<GradesListScreen> createState() => _GradesListScreenState();
}

class _GradesListScreenState extends State<GradesListScreen> {
  final _db = DatabaseService();
  List<ClassModel> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await _db.getClasses();
      setState(() {
        _classes = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: _classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grade_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('لا توجد فصول', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text(
                    'أنشئ فصلاً أولاً من تبويب الفصول',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _classes.length,
                itemBuilder: (context, index) {
                  final cls = _classes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber.withOpacity(0.15),
                        child: const Icon(Icons.grade, color: Colors.amber),
                      ),
                      title: Text(cls.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(cls.subject ?? 'اضغط لإدارة الدرجات'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClassDetailScreen(classModel: cls),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

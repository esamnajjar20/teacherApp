import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'حدث خطأ في الخادم']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'لا يوجد اتصال بالإنترنت']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'خطأ في التخزين المحلي']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'فشل في المصادقة']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'بيانات غير صالحة']);
}

class ConflictFailure extends Failure {
  const ConflictFailure([super.message = 'يوجد تعارض في البيانات']);
}

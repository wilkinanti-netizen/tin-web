import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uber_clone/features/auth/data/auth_repository.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;

  AuthController(this._authRepository) : super(const AsyncData(null));

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.signInWithEmailAndPassword(email, password));
  }

  Future<void> signUp(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.createUserWithEmailAndPassword(email, password));
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
  }
}

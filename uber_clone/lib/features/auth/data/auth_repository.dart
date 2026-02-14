import 'package:flutter_riverpod/flutter_riverpod.dart';

// Interface
abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<void> signInWithEmailAndPassword(String email, String password);
  Future<void> createUserWithEmailAndPassword(String email, String password);
  Future<void> signOut();
}

// Simple User Model for Mocking
class User {
  final String uid;
  final String email;
  
  User({required this.uid, required this.email});
}

// Mock Implementation
class MockAuthRepository implements AuthRepository {
  // Simulating a logged-in state or null
  // For now, let's just use a simple StreamController if we needed dynamic updates,
  // but for a basic mock, we can just return success.
  
  @override
  Stream<User?> get authStateChanges => Stream.value(null); // Combine with StateNotifier for real mock updates if needed

  @override
  User? get currentUser => null; // Mock: assume logged out initially

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    // In a real mock, we would update the stream here.
    print("Mock Sign In: $email");
  }

  @override
  Future<void> createUserWithEmailAndPassword(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    print("Mock Sign Up: $email");
  }

  @override
  Future<void> signOut() async {
     await Future.delayed(const Duration(milliseconds: 500));
     print("Mock Sign Out");
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

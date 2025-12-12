import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/agency_service.dart';

class LoginController {
  LoginController({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client,
      _agencyService = AgencyService(client: client);

  final SupabaseClient _client;
  final AgencyService _agencyService;

  Future<String?> login(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return 'Unable to sign in. Please try again.';
    }
  }

  Future<String?> signUp(
    String email,
    String password,
    String agencyCode,
    String firstName,
    String lastName,
  ) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return 'Unable to create account. Please try again.';
      }

      // Ensure we have a session so RLS checks pass
      if (_client.auth.currentSession == null) {
        try {
          await _client.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } on AuthException catch (error) {
          return error.message;
        }
      }

      await _agencyService.ensureMembershipWithCode(
        agencyCode,
        firstName: firstName,
        lastName: lastName,
      );
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (error) {
      return error.toString();
    }
  }

  Future<void> logout() => _client.auth.signOut();

  bool get hasActiveSession => _client.auth.currentSession != null;
}

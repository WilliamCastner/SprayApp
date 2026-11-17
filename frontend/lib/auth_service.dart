import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign in with email
  Future<AuthResponse> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Validate username format
  String? validateUsername(String username) {
    if (username.isEmpty) {
      return 'Username cannot be empty';
    }
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (username.length > 20) {
      return 'Username must be 20 characters or less';
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, _ and -';
    }
    return null;
  }

  // Check if username is already taken
  Future<bool> isUsernameTaken(String username) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('display_name', username)
          .maybeSingle();
      return response != null;
    } catch (e) {
      // If profiles table doesn't exist yet or other error, allow attempt
      return false;
    }
  }

  // Sign up with email
  Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password,
    String username,
  ) async {
    // Validate username format
    final validationError = validateUsername(username);
    if (validationError != null) {
      throw AuthException(validationError);
    }

    // Check if username is taken
    final isTaken = await isUsernameTaken(username);
    if (isTaken) {
      throw AuthException('Username is already taken');
    }

    // Sign up with username in metadata
    // The database trigger will create the profile entry
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': username},
    );

    // If signup was successful but trigger didn't create profile,
    // manually insert it (fallback)
    if (response.user != null) {
      try {
        await _supabase.from('profiles').upsert({
          'id': response.user!.id,
          'display_name': username,
        });
      } catch (e) {
        // Profile might already exist from trigger, that's ok
      }
    }

    return response;
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Permanently delete the signed-in account and everything it owns.
  ///
  /// Video files live in storage, which SQL can't clean up, so remove them
  /// here first; the `delete_user` database function then removes the rows
  /// (sends, comments, likes, saves, videos, climbs, profile, login).
  /// Ends with a local sign-out so no stale session is left behind.
  Future<void> deleteAccount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw AuthException('No user logged in');
    }

    try {
      final videos = await _supabase
          .from('beta_videos')
          .select('storage_path')
          .eq('user_id', user.id);
      final paths = <String>[
        for (final v in videos)
          if (v['storage_path'] is String) ...[
            v['storage_path'] as String,
            (v['storage_path'] as String).replaceAll('.mp4', '_thumb.jpg'),
          ],
      ];
      if (paths.isNotEmpty) {
        await _supabase.storage.from('beta-videos').remove(paths);
      }
    } catch (_) {
      // Files are best effort; never block deleting the account.
    }

    try {
      await _supabase.rpc('delete_user');
    } catch (e) {
      throw AuthException('Failed to delete account: $e');
    }
    await _supabase.auth.signOut();
  }

  /// Change the display name everywhere it appears (profile, climbs set,
  /// sends, comments, videos, likes) in one database call, so stats and
  /// profile pages don't split between the old and new name.
  Future<void> renameUser(String newName) async {
    final error = validateUsername(newName);
    if (error != null) throw AuthException(error);
    try {
      await _supabase.rpc('rename_user', params: {'new_name': newName});
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
      // Function not installed yet: old behaviour (profile only).
      await _supabase.from('profiles').upsert({
        'id': _supabase.auth.currentUser!.id,
        'display_name': newName,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    await _supabase.auth.updateUser(UserAttributes(data: {'display_name': newName}));
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://williamcastner.github.io/SprayApp/reset-password.html',
    );
  }

  String? getCurrentEmail() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }

  // Get current user's display name
  String? getCurrentDisplayName() {
    final user = _supabase.auth.currentUser;
    return user?.userMetadata?['display_name'];
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }
}
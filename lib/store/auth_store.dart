import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which identity provider the user signed in with.
enum AuthProvider { google, microsoft, apple }

/// A minimal signed-in account record. Real provider tokens (e.g. the
/// Google OAuth access token used for Sheets access) are NOT stored here —
/// they live in memory inside the relevant provider service
/// (see GoogleAuthService) for the lifetime of the session, and Google's
/// own GoogleSignIn plugin silently re-authenticates on app restart.
class AuthAccount {
  final AuthProvider provider;
  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;

  const AuthAccount({
    required this.provider,
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() => {
        'provider': provider.name,
        'id': id,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
      };

  factory AuthAccount.fromMap(Map<String, dynamic> map) => AuthAccount(
        provider: AuthProvider.values.firstWhere(
          (p) => p.name == map['provider'],
          orElse: () => AuthProvider.google,
        ),
        id: map['id'] as String,
        displayName: map['displayName'] as String,
        email: map['email'] as String,
        photoUrl: map['photoUrl'] as String?,
      );
}

/// Tracks the current signed-in account across the app and persists a
/// lightweight record of it (not tokens) so the welcome screen can show
/// "Signed in as ..." without re-prompting unnecessarily.
class AuthStore extends ChangeNotifier {
  static final AuthStore _instance = AuthStore._internal();
  factory AuthStore() => _instance;
  AuthStore._internal();

  AuthAccount? _account;
  AuthAccount? get account => _account;
  bool get isSignedIn => _account != null;

  static const _kProvider = 'auth_provider';
  static const _kId = 'auth_id';
  static const _kName = 'auth_name';
  static const _kEmail = 'auth_email';
  static const _kPhoto = 'auth_photo';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString(_kProvider);
    if (providerName == null) {
      _account = null;
      notifyListeners();
      return;
    }
    _account = AuthAccount(
      provider: AuthProvider.values.firstWhere(
        (p) => p.name == providerName,
        orElse: () => AuthProvider.google,
      ),
      id: prefs.getString(_kId) ?? '',
      displayName: prefs.getString(_kName) ?? '',
      email: prefs.getString(_kEmail) ?? '',
      photoUrl: prefs.getString(_kPhoto),
    );
    notifyListeners();
  }

  Future<void> signIn(AuthAccount account) async {
    _account = account;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProvider, account.provider.name);
    await prefs.setString(_kId, account.id);
    await prefs.setString(_kName, account.displayName);
    await prefs.setString(_kEmail, account.email);
    if (account.photoUrl != null) {
      await prefs.setString(_kPhoto, account.photoUrl!);
    } else {
      await prefs.remove(_kPhoto);
    }
  }

  Future<void> signOut() async {
    _account = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProvider);
    await prefs.remove(_kId);
    await prefs.remove(_kName);
    await prefs.remove(_kEmail);
    await prefs.remove(_kPhoto);
  }
}

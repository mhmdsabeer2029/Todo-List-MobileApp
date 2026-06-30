import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../store/auth_store.dart';

/// Wraps `google_sign_in` to provide:
///  1. Basic "Sign in with Google" (profile + email) for the account screen.
///  2. An authenticated HTTP client carrying the Sheets/Drive readonly
///     OAuth scopes, used by SheetsImportService to list and fetch
///     spreadsheets from the signed-in user's Drive.
///
/// IMPORTANT SETUP STEP (cannot be done from inside the app):
/// Google Sign-In requires an OAuth client registered in the Google Cloud
/// Console for this app's package name + SHA-1 signing fingerprint
/// (Android) and bundle ID (iOS). Until that's configured, calls here will
/// throw a `PlatformException` with code `sign_in_failed` / `10`. See the
/// setup guide in [setupInstructions].
class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  /// Scopes needed to read (not modify) the user's spreadsheets and to list
  /// files in Drive so we can show a picker of available sheets.
  static const _scopes = <String>[
    'email',
    'https://www.googleapis.com/auth/spreadsheets.readonly',
    'https://www.googleapis.com/auth/drive.readonly',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Triggers the interactive Google sign-in flow and, on success, stores a
  /// lightweight [AuthAccount] record via [AuthStore]. Returns true on
  /// success, false if the user cancelled.
  Future<bool> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return false; // user cancelled
    _currentUser = account;

    await AuthStore().signIn(AuthAccount(
      provider: AuthProvider.google,
      id: account.id,
      displayName: account.displayName ?? account.email,
      email: account.email,
      photoUrl: account.photoUrl,
    ));
    return true;
  }

  /// Attempts to silently restore a previous Google session (no UI shown).
  Future<bool> trySilentSignIn() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return false;
      _currentUser = account;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Returns an authorization header for the currently signed-in Google
  /// account, refreshing the access token if necessary. Throws if not
  /// signed in.
  Future<Map<String, String>> _authHeaders() async {
    final user = _currentUser ?? await _googleSignIn.signInSilently();
    if (user == null) {
      throw StateError('Not signed in with Google.');
    }
    _currentUser = user;
    final auth = await user.authentication;
    return {
      'Authorization': 'Bearer ${auth.accessToken}',
      'Accept': 'application/json',
    };
  }

  /// Lists the user's Google Sheets files (id + name), most recently
  /// modified first, via the Drive v3 API.
  Future<List<DriveFile>> listSpreadsheets({int pageSize = 25}) async {
    final headers = await _authHeaders();
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': "mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
      'fields': 'files(id,name,modifiedTime,iconLink)',
      'orderBy': 'modifiedTime desc',
      'pageSize': '$pageSize',
    });
    final response = await http.get(uri, headers: headers);
    if (response.statusCode >= 400) {
      throw Exception('Drive API error ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final files = (decoded['files'] as List<dynamic>? ?? [])
        .map((f) => DriveFile.fromJson(f as Map<String, dynamic>))
        .toList();
    return files;
  }

  /// Fetches every cell value from every visible sheet/tab in a spreadsheet
  /// as a precise grid (rows of strings), reading each tab's full range via
  /// the Sheets v4 values API.
  Future<Map<String, List<List<String>>>> fetchSpreadsheetData(String spreadsheetId) async {
    final headers = await _authHeaders();

    // 1. Get sheet/tab names.
    final metaUri = Uri.https(
      'sheets.googleapis.com',
      '/v4/spreadsheets/$spreadsheetId',
      {'fields': 'sheets.properties.title'},
    );
    final metaResponse = await http.get(metaUri, headers: headers);
    if (metaResponse.statusCode >= 400) {
      throw Exception('Sheets API error ${metaResponse.statusCode}: ${metaResponse.body}');
    }
    final meta = jsonDecode(metaResponse.body) as Map<String, dynamic>;
    final sheetTitles = (meta['sheets'] as List<dynamic>? ?? [])
        .map((s) => (s['properties']['title'] as String))
        .toList();

    // 2. Pull values for each tab.
    final result = <String, List<List<String>>>{};
    for (final title in sheetTitles) {
      final valuesUri = Uri.https(
        'sheets.googleapis.com',
        '/v4/spreadsheets/$spreadsheetId/values/${Uri.encodeComponent(title)}',
        {'valueRenderOption': 'FORMATTED_VALUE'},
      );
      final valuesResponse = await http.get(valuesUri, headers: headers);
      if (valuesResponse.statusCode >= 400) continue; // skip unreadable tabs
      final valuesJson = jsonDecode(valuesResponse.body) as Map<String, dynamic>;
      final rows = (valuesJson['values'] as List<dynamic>? ?? [])
          .map((row) => (row as List<dynamic>).map((cell) => cell.toString()).toList())
          .toList();
      result[title] = rows;
    }
    return result;
  }

  static const String setupInstructions = '''
To enable real Google Sign-In and Sheets access:

1. Go to https://console.cloud.google.com and create (or select) a project.
2. Enable the "Google Sheets API" and "Google Drive API".
3. Go to "APIs & Services > Credentials" and create an OAuth 2.0 Client ID:
   - Android: provide the app's package name (com.example.todolist) and
     SHA-1 signing fingerprint (get it with:
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     for debug builds; use your release keystore's SHA-1 for release builds).
   - iOS: provide the bundle ID and add the generated REVERSED_CLIENT_ID
     as a URL scheme in Info.plist.
4. Configure the OAuth consent screen (you can keep it in "Testing" mode and
   add your own Google account as a test user while developing).
5. No client secret or API key needs to be pasted into this app's code -
   google_sign_in handles the native OAuth flow using the platform
   configuration above.
''';
}

class DriveFile {
  final String id;
  final String name;
  final String? modifiedTime;
  final String? iconLink;

  const DriveFile({
    required this.id,
    required this.name,
    this.modifiedTime,
    this.iconLink,
  });

  factory DriveFile.fromJson(Map<String, dynamic> json) => DriveFile(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled spreadsheet',
        modifiedTime: json['modifiedTime'] as String?,
        iconLink: json['iconLink'] as String?,
      );
}

import 'package:url_launcher/url_launcher.dart';
import '../store/auth_store.dart';

/// Microsoft sign-in via Azure AD / Microsoft Identity Platform.
///
/// A fully native Flutter flow needs the `aad_oauth` or
/// `msal_auth` package plus an app registration in
/// https://portal.azure.com (Azure Active Directory > App registrations).
/// That registration requires a redirect URI you control, which isn't
/// possible to generate from inside this conversation, so this service
/// currently launches the standard Microsoft OAuth consent page in the
/// browser as a starting point. Swap in `msal_auth` once you have:
///   1. An Azure AD app registration (Application (client) ID)
///   2. A registered redirect URI, e.g. msauth://com.example.todolist/<signature>
///   3. The "Mobile and desktop applications" platform configured
/// and replace [signIn] below with the package's interactive sign-in call.
class MicrosoftAuthService {
  static const String setupInstructions = '''
To enable real Microsoft Sign-In:
1. Go to https://portal.azure.com > Azure Active Directory > App registrations > New registration.
2. Set "Supported account types" to whatever fits (personal + work accounts is broadest).
3. Under Authentication, add a platform: Android/iOS, with redirect URI
   msauth://<your.package.name>/<base64-encoded-signature-hash>.
4. Copy the "Application (client) ID" into your app config.
5. Add the `msal_auth` package and replace the placeholder in
   MicrosoftAuthService.signIn() with MsalAuth's acquireToken(...) call.
''';

  /// Placeholder: opens Microsoft's OAuth page in the browser. Replace with
  /// msal_auth's native interactive flow once the Azure app registration
  /// above is complete — this stub does not yet write a real AuthAccount.
  Future<bool> signIn({required String clientId, required String redirectUri}) async {
    final uri = Uri.https('login.microsoftonline.com', '/common/oauth2/v2.0/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'scope': 'User.Read offline_access',
    });
    if (clientId.isEmpty) {
      throw StateError('Microsoft sign-in is not configured yet. '
          'See MicrosoftAuthService.setupInstructions.');
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Apple sign-in via Sign in with Apple.
///
/// On iOS this works natively once Sign in with Apple is enabled as a
/// capability in Xcode (Signing & Capabilities) for the app's bundle ID in
/// your Apple Developer account — that's an Xcode-project + Apple Developer
/// Portal step that has to happen on your machine. Once enabled, replace
/// [signIn] below with the `sign_in_with_apple` package's
/// SignInWithApple.getAppleIDCredential(...) call.
class AppleAuthService {
  static const String setupInstructions = '''
To enable real Sign in with Apple:
1. In your Apple Developer account, enable "Sign In with Apple" for your App ID.
2. In Xcode, open ios/Runner.xcworkspace > Signing & Capabilities > "+ Capability" > Sign In with Apple.
3. Add the `sign_in_with_apple` package to pubspec.yaml.
4. Replace the placeholder in AppleAuthService.signIn() with:
   SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName])
5. Note: Sign in with Apple has no equivalent on Android without a separate
   web-based "Sign in with Apple JS" flow.
''';

  Future<bool> signIn() async {
    throw UnimplementedError(
      'Sign in with Apple requires the sign_in_with_apple package and an '
      'Xcode capability. See AppleAuthService.setupInstructions.',
    );
  }
}

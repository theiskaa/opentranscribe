import 'package:url_launcher/url_launcher.dart';

/// The project repository, the one outward link the app offers.
const kRepoUrl = 'https://github.com/theiskaa/opentranscribe';

/// Hands a link to the system browser. The APP opens no socket - the OS does,
/// for a public URL that carries no user data. This is the one place the app
/// points outward; see the one rule in CLAUDE.md.
///
/// [externalApplication] so the link opens in the real browser, not an in-app
/// web view (which would be the app fetching, not the OS). Returns whether the
/// launch was accepted; a caller may surface a failure, or ignore it.
///
/// No `canLaunchUrl` probe: it needs an `LSApplicationQueriesSchemes` entry to
/// answer for arbitrary schemes and throws a channel error otherwise, and for a
/// plain https link it buys nothing - `launchUrl` reports its own failure.
Future<bool> openLink(String url) async {
  final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Jumps to this app's page in the system Settings. Kept apart from [openLink],
/// whose https fixup would mangle the scheme. Same one-rule story: the OS
/// handles it, nothing is fetched.
Future<bool> openAppSettings() async {
  try {
    return await launchUrl(Uri.parse('app-settings:'), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

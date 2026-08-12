import 'package:url_launcher/url_launcher.dart';

/// The outward links the app offers, all opened through [openLink]: the
/// project repository, and the support screen's compliance pair.
const kRepoUrl = 'https://github.com/theiskaa/opentranscribe';

/// The new-issue page, where a user can request a theme (or anything else).
const kNewIssueUrl = '$kRepoUrl/issues/new';

/// The published privacy policy, linked where a subscription is sold
/// (guideline 3.1.2) and saying nothing the app does not do.
const kPrivacyUrl = 'https://opentranscribe.xyz/privacy';

/// Apple's standard EULA, the terms the subscription runs on. The stable
/// Apple-published address review expects; no custom terms exist.
const kTermsUrl = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

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

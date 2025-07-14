// ignore_for_file: avoid_web_libraries_in_flutter, depend_on_referenced_packages
import 'package:web/web.dart' as html;
import 'security.dart'; // import the Security class above

class CookiesManagement {
  static bool accessCookiesExist() {
    String accessToken = decryptAndGetCookie('access_token');
    String refreshToken = decryptAndGetCookie('refresh_token');

    return accessToken.isNotEmpty && refreshToken.isNotEmpty;
  }

  static void encryptAndSetCookie(String cookieName, String cookieValue) {
    Map<String, String> mapCookie = {cookieName: cookieValue};
    String encryptedCookie = '';
    if (cookieValue.isNotEmpty) {
      encryptedCookie = Security.encryptJson(mapCookie);
    }
    String encryptedCookieValue = '$cookieName=$encryptedCookie';
    html.document.cookie =
        "$encryptedCookieValue; Max-Age=31536000; path=/; secure; samesite=strict";
  }

  static String decryptAndGetCookie(String cookieName) {
    String cookies = html.document.cookie ?? '';
    String cookieValue = '';

    for (var cookie in cookies.split(';')) {
      if (cookie.trim().startsWith('$cookieName=')) {
        cookieValue = cookie.trim().substring(cookieName.length + 1);
        break;
      }
    }

    if (cookieValue.isEmpty) {
      return '';
    }

    Map<String, dynamic> cookieMap = Security.decryptJson(cookieValue);
    return cookieMap[cookieName]?.toString() ?? '';
  }
}

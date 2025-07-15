import 'package:ime_common/handlers/cookies_managment.dart';
import 'package:ime_common/imports.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:ime_common/messages/sessionExpiredMsg.dart';

class ApiCall {
  static Future<String?> validateAccessToken(BuildContext context,
      {bool fromRouteRedirect = false,
      String refreshTokenPath = '/refresh_token'}) async {
    try {
      final appBox = Hive.box<App>('apps');

      //read token from cookies
      String accessToken = CookiesManagment.decryptAndGetCookie('access_token');

      if (accessToken == '') {
        //navigate to login page
        if (!fromRouteRedirect) {
          context.go('/externalRedirect', extra: {"replace": true});
        }
        return null;
      }

      final jwt = JWT.decode(accessToken);

      final expDate =
          DateTime.fromMillisecondsSinceEpoch(jwt.payload['exp'] * 1000);

      if (expDate.isBefore(DateTime.now()) || appBox.isEmpty) {
        //expired -> request an new one
        //get refresh token from cookies
        String refreshToken =
            CookiesManagment.decryptAndGetCookie('refresh_token');
        if (refreshToken == '') {
          await showTokenExpirationMsg(context);
          return null;
        }
        //call refresh token method
        String selectedBranch = '';
        try {
          selectedBranch =
              CookiesManagment.decryptAndGetCookie('selected_branch');
        } on Exception catch (e) {
          if (kDebugMode) {
            print(e);
          }
          selectedBranch = '';
        }

        http.Response response;
        if (selectedBranch.isEmpty || selectedBranch == '') {
          response = await makeHttpRequest(
              context, Method.get, refreshTokenPath,
              extraHeaders: {"refresh_token": refreshToken},
              showAlertErrors: false,
              isRefreshTokenCall: true);
        } else {
          String encryptedId = Security.encryptString(selectedBranch);
          String encodedEncrypted = Uri.encodeComponent(encryptedId);
          response = await makeHttpRequest(context, Method.get,
              '$refreshTokenPath?selected_branch=$encodedEncrypted',
              extraHeaders: {"refresh_token": refreshToken},
              showAlertErrors: false,
              isRefreshTokenCall: true);
        }

        if (response.statusCode == 401) {
          if (!fromRouteRedirect) {
            await showTokenExpirationMsg(context);
          }
          return null;
        }

        if (response.statusCode == 200) {
          //new access token
          accessToken = Security.decryptJson(
              json.decode(response.body)['encrypted_data'])['access_token'];

          CookiesManagment.encryptAndSetCookie('access_token', accessToken);

          //set apps to AppBox
          List<dynamic> appData = Security.decryptJson(
              json.decode(response.body)['encrypted_data'])['apps'];

          await appBox.clear();
          for (dynamic app in appData) {
            await appBox.add(App.fromJson(app));
          }
        }
      }

      //set user and apps to provider
      if (accessToken != '') {
        final jwt = JWT.decode(accessToken);

        final user = User.fromJson(jwt.payload);
        final appBarProvider =
            Provider.of<AppBarProvider>(context, listen: false);
        for (var i = 0; i < appBox.length; i++) {
          final App? app = appBox.getAt(i);
          user.apps?.add(app);
        }
        appBarProvider.setLoginUser(user);
      }

      return accessToken;
    } on JWTException catch (ex) {
      if (!fromRouteRedirect) {
        showAlertMsg(
            context: context,
            title: getCommonTranslated(context, 'becareful'),
            content: ex.toString(),
            buttonText: 'OK');
      }

      return null;
    } catch (err) {
      if (!fromRouteRedirect) {
        showAlertMsg(
            context: context,
            title: getCommonTranslated(context, 'becareful'),
            content: err.toString(),
            buttonText: 'OK');
      }

      return null;
    }
  }

  static Future<http.Response> makeHttpRequest(
    BuildContext context,
    Method method,
    String url, {
    dynamic body,
    String? token,
    bool isRefreshTokenCall = false,
    Map<String, String>? extraHeaders,
    bool showAlertErrors = true,
  }) async {
    //check access token
    String? checkedAccessToken;
    if (token == null) {
      if (!isRefreshTokenCall) {
        checkedAccessToken = await validateAccessToken(context);
      } else {
        checkedAccessToken =
            CookiesManagment.decryptAndGetCookie('access_token');
      }

      if (checkedAccessToken == null) {
        return http.Response('{"message": "Token validation error"}', 500);
      }
    }

    //add headers
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': token ?? 'Bearer $checkedAccessToken'
    };
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    //encrypt body
    if (body != null) {
      final encryptedValue = Security.encryptJson(body);
      final finalBody = jsonEncode({"encrypted_data": encryptedValue});
      body = finalBody;
    }

    debugPrint('${Uri.parse((dotenv.env['SERVICE_URL'] ?? '') + url)}');

    //GET
    if (method == Method.get) {
      return await http
          .get(Uri.parse((dotenv.env['SERVICE_URL'] ?? '') + url),
              headers: headers)
          .then((http.Response response) {
        if (response.statusCode != 200 && showAlertErrors) {
          showAlertMsg(
              context: context,
              title: getCommonTranslated(context, 'becareful'),
              content: response.body.contains('encrypted_data')
                  ? Security.decryptJson(json
                          .decode(response.body)['encrypted_data'])['message']
                      .toString()
                  : json.decode(response.body)['message'],
              buttonText: 'OK');
        }
        return response;
      }).catchError((err) {
        debugPrint(err.toString());
        if (showAlertErrors) {
          showAlertMsg(
              context: context,
              title: getCommonTranslated(context, 'becareful'),
              content: err.toString(),
              buttonText: 'OK');
        }

        return http.Response('{"message": "${err.toString()}"}', 500);
      }).timeout(const Duration(seconds: 90), onTimeout: () {
        debugPrint('timeout error');
        if (showAlertErrors) {
          showAlertMsg(
              context: context,
              title: 'Timeout',
              content: getCommonTranslated(context, 'timeoutErr'),
              buttonText: 'OK');
        }
        return http.Response('{"message": "Timeout Error"}', 500);
      });
    }
    //POST
    if (method == Method.post) {
      return await http
          .post(Uri.parse((dotenv.env['SERVICE_URL'] ?? '') + url),
              headers: headers, body: body)
          .then((http.Response response) {
        if (response.statusCode != 200 &&
            response.statusCode != 201 &&
            showAlertErrors) {
          showAlertMsg(
              context: context,
              title: getCommonTranslated(context, 'becareful'),
              content: response.body.contains('encrypted_data')
                  ? Security.decryptJson(json
                          .decode(response.body)['encrypted_data'])['message']
                      .toString()
                  : json.decode(response.body)['message'],
              buttonText: 'OK');
        }
        return response;
      }).catchError((err) {
        debugPrint(err);
        if (showAlertErrors) {
          showAlertMsg(
              context: context,
              title: getCommonTranslated(context, 'becareful'),
              content: err.toString(),
              buttonText: 'OK');
        }
        return http.Response('{"message": "${err.toString()}"}', 500);
      }).timeout(const Duration(seconds: 90), onTimeout: () {
        debugPrint('timeout error');
        if (showAlertErrors) {
          showAlertMsg(
              context: context,
              title: 'Timeout',
              content: getCommonTranslated(context, 'timeoutErr'),
              buttonText: 'OK');
        }
        return http.Response('{"message": "Timeout Error"}', 500);
      });
    }
    //PUT
    if (method == Method.put) {
      return await http
          .put(Uri.parse((dotenv.env['SERVICE_URL'] ?? '') + url),
              headers: headers, body: body)
          .then((http.Response response) {
        if (response.statusCode != 200 && showAlertErrors) {
          showAlertMsg(
              context: context,
              title: getCommonTranslated(context, 'becareful'),
              content: response.body.contains('encrypted_data')
                  ? Security.decryptJson(json
                          .decode(response.body)['encrypted_data'])['message']
                      .toString()
                  : json.decode(response.body)['message'],
              buttonText: 'OK');
        }
        return response;
      }).catchError((err) {
        debugPrint(err);
        if (showAlertErrors) {
          showAlertMsg(
              context: context,
              title: getCommonTranslated(context, 'becareful'),
              content: err.toString(),
              buttonText: 'OK');
        }
        return http.Response('{"message": "${err.toString()}"}', 500);
      }).timeout(const Duration(seconds: 90), onTimeout: () {
        debugPrint('timeout error');
        if (showAlertErrors) {
          showAlertMsg(
              context: context,
              title: 'Timeout',
              content: getCommonTranslated(context, 'timeoutErr'),
              buttonText: 'OK');
        }
        return http.Response('{"message": "Timeout Error"}', 500);
      });
    }
    //PATCH
    if (method == Method.patch) {
      return await http
          .patch(Uri.parse((dotenv.env['SERVICE_URL'] ?? '') + url),
              headers: headers, body: body)
          .then((http.Response response) {
        if (response.statusCode != 200 && showAlertErrors) {
          showAlertMsg(
              context: context,
              title: getCommonTranslated(context, 'becareful'),
              content: response.body.contains('encrypted_data')
                  ? Security.decryptJson(json
                          .decode(response.body)['encrypted_data'])['message']
                      .toString()
                  : json.decode(response.body)['message'],
              buttonText: 'OK');
        }
        return response;
      }).catchError((err) {
        debugPrint(err);
        if (showAlertErrors) {
          showAlertMsg(
              context: context,
              title: getCommonTranslated(context, 'becareful'),
              content: err.toString(),
              buttonText: 'OK');
        }
        return http.Response('{"message": "${err.toString()}"}', 500);
      }).timeout(const Duration(seconds: 90), onTimeout: () {
        debugPrint('timeout error');
        if (showAlertErrors) {
          showAlertMsg(
              context: context,
              title: 'Timeout',
              content: getCommonTranslated(context, 'timeoutErr'),
              buttonText: 'OK');
        }
        return http.Response('{"message": "Timeout Error"}', 500);
      });
    }
    //DELETE
    if (method == Method.delete) {
      return await http
          .delete(Uri.parse((dotenv.env['SERVICE_URL'] ?? '') + url),
              headers: headers, body: body)
          .then((http.Response response) {
        if (response.statusCode != 200 && showAlertErrors) {
          showAlertMsg(
              context: context,
              title: getCommonTranslated(context, 'becareful'),
              content: response.body.contains('encrypted_data')
                  ? Security.decryptJson(json
                          .decode(response.body)['encrypted_data'])['message']
                      .toString()
                  : json.decode(response.body)['message'],
              buttonText: 'OK');
        }
        return response;
      }).catchError((err) {
        debugPrint(err);
        if (showAlertErrors) {
          showAlertMsg(
              context: context,
              title: getCommonTranslated(context, 'becareful'),
              content: err.toString(),
              buttonText: 'OK');
        }
        return http.Response('{"message": "${err.toString()}"}', 500);
      }).timeout(const Duration(seconds: 90), onTimeout: () {
        debugPrint('timeout error');
        if (showAlertErrors) {
          showAlertMsg(
              context: context,
              title: 'Timeout',
              content: getCommonTranslated(context, 'timeoutErr'),
              buttonText: 'OK');
        }
        return http.Response('{"message": "Timeout Error"}', 500);
      });
    }

    return http.Response('{"message": "General Error"}', 500);
  }
}

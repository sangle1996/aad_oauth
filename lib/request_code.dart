import 'dart:async';
import 'request/authorization_request.dart';
import 'model/config.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io';

class RequestCode {
  final StreamController<String> _onCodeListener = StreamController();
  final FlutterWebviewPlugin _webView = FlutterWebviewPlugin();
  final Config _config;
  AuthorizationRequest _authorizationRequest;

  var _onCodeStream;

  RequestCode(Config config) : _config = config {
    _authorizationRequest = AuthorizationRequest(config);
  }

  Future<String> requestCode() async {
    String code;
    final urlParams = _constructUrlParams();
    if(Platform.isIOS){
      final CustomInAppBrowser browser = new CustomInAppBrowser();
      browser.openUrlRequest(
        urlRequest: URLRequest(url: Uri.parse('${_authorizationRequest.url}?$urlParams')),
        options: InAppBrowserClassOptions(
            crossPlatform: InAppBrowserOptions(
              hideUrlBar: true,
            ),
            android: AndroidInAppBrowserOptions(
              allowGoBackWithBackButton: true,
              closeOnCannotGoBack: false,
              shouldCloseOnBackButtonPressed: false,

            ),
            ios: IOSInAppBrowserOptions(
                transitionStyle: IOSUIModalTransitionStyle.CROSS_DISSOLVE,
                hideToolbarBottom: true
            ),
            inAppWebViewGroupOptions: InAppWebViewGroupOptions(
                crossPlatform: InAppWebViewOptions(
                  clearCache: true,
                  javaScriptEnabled: true,
                  userAgent: _config.userAgent,
                )
            )),
      );
      browser.listenStart = (value){
        if(value == null){
          _onCodeListener.add(null);
        }
        var uri = value;
        if (uri.queryParameters['error'] != null) {
          browser.close();
          _onCodeListener.add(null);
        }

        if (uri.queryParameters['code'] != null) {
          browser.close();
          _onCodeListener.add(uri.queryParameters['code']);
        }
      };
    }else{
      await _webView.launch(
        Uri.encodeFull('${_authorizationRequest.url}?$urlParams'),
        clearCookies: _authorizationRequest.clearCookies,
        hidden: false,
        rect: _config.screenSize,
        userAgent: _config.userAgent,
      );

      _webView.onUrlChanged.listen((String url) {
        var uri = Uri.parse(url);

        if (uri.queryParameters['error'] != null) {
          _webView.close();
          _onCodeListener.add(null);
        }

        if (uri.queryParameters['code'] != null) {
          _webView.close();
          _onCodeListener.add(uri.queryParameters['code']);
        }
      });
    }
    code = await _onCode.first;
    return code;
  }

  void sizeChanged() {
    _webView.resize(_config.screenSize);
  }

  Future<void> clearCookies() async {
    final urlParams = _constructUrlParams();
    if(Platform.isIOS){
      final CustomInAppBrowser browser = new CustomInAppBrowser();
      browser.openUrlRequest(
        urlRequest: URLRequest(url: Uri.parse('${_authorizationRequest.url}?$urlParams')),
        options: InAppBrowserClassOptions(
            crossPlatform: InAppBrowserOptions(
              hidden: true,
            ),
            inAppWebViewGroupOptions: InAppWebViewGroupOptions(
                crossPlatform: InAppWebViewOptions(
                  javaScriptEnabled: true,
                  userAgent: _config.userAgent,

                  clearCache: true,
                )
            )),
      );
      browser.close();
    }
    await _webView.launch('', hidden: true, clearCookies: true);
    await _webView.close();
  }

  Stream<String> get _onCode =>
      _onCodeStream ??= _onCodeListener.stream.asBroadcastStream();

  String _constructUrlParams() =>
      _mapToQueryParams(_authorizationRequest.parameters);

  String _mapToQueryParams(Map<String, String> params) {
    final queryParams = <String>[];
    params
        .forEach((String key, String value) => queryParams.add('$key=$value'));
    return queryParams.join('&');
  }
}


class CustomInAppBrowser extends InAppBrowser {
  Function listenStart;
  @override
  Future onBrowserCreated() async {
  }

  @override
  Future onLoadStart(url) async {
  }

  @override
  Future onLoadStop(url) async {
    listenStart(url);
  }

  @override
  void onLoadError(url, code, message) {
    listenStart(url);
  }

  @override
  void onProgressChanged(progress) {
  }

  @override
  void onExit() {
    listenStart(null);
  }
}

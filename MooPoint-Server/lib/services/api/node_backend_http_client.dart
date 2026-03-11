import 'package:http/http.dart' as http;

import 'node_backend_http_client_io.dart'
    if (dart.library.html) 'node_backend_http_client_web.dart';

class _NonClosingClient extends http.BaseClient {
  final http.Client _inner;

  _NonClosingClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    // Intentionally no-op: the app uses many short-lived services that call
    // dispose(), but we want to keep a shared session (cookies) alive.
  }
}

final http.Client _sharedClient = createClientImpl();

http.Client createNodeBackendHttpClient() => _NonClosingClient(_sharedClient);

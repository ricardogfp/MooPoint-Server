import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

http.Client createClientImpl() {
  final c = BrowserClient();
  c.withCredentials = true;
  return c;
}

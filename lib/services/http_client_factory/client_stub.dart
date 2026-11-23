import 'package:http/http.dart' as http;

http.Client createHttpClient() =>
    throw UnsupportedError('Cannot create HTTP client on this platform.');

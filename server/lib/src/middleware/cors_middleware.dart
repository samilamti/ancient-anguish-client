import 'package:shelf/shelf.dart';

/// Creates middleware that adds CORS headers to all responses and
/// handles preflight OPTIONS requests.
Middleware createCorsMiddleware(List<String> allowedOrigins) {
  return (Handler innerHandler) {
    return (Request request) async {
      // Determine the origin to allow.
      final requestOrigin = request.headers['origin'];
      final allowOrigin = allowedOrigins.contains('*')
          ? '*'
          : (requestOrigin != null && allowedOrigins.contains(requestOrigin))
              ? requestOrigin
              : '';

      final corsHeaders = <String, String>{
        'Access-Control-Allow-Origin': allowOrigin,
        'Access-Control-Allow-Methods': 'GET, POST, PUT, HEAD, DELETE, OPTIONS',
        'Access-Control-Allow-Headers':
            'Origin, Content-Type, Authorization, Accept',
        'Access-Control-Expose-Headers':
            'X-File-Exists, X-File-Length, Content-Length',
        'Access-Control-Max-Age': '86400',
      };

      // Handle preflight.
      if (request.method == 'OPTIONS') {
        return Response(204, headers: corsHeaders);
      }

      final response = await innerHandler(request);
      return response.change(headers: corsHeaders);
    };
  };
}

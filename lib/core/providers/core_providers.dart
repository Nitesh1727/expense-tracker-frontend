import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

/// One ApiClient instance for the app's lifetime — feature data-layer
/// classes take it as a constructor dependency instead of constructing
/// their own Dio, so the auth interceptor/onUnauthorized hook is shared.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

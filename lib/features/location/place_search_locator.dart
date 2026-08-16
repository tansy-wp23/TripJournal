import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'place_search_service.dart';

typedef SupabasePlaceFunctionCall =
    Future<FunctionResponse> Function(
      String functionName, {
      required Map<String, dynamic> body,
    });

PlaceSearchService get placeSearchService => SupabasePlaceSearchService(
  invoke: buildPlaceFunctionInvoker(
    call: (functionName, {required body}) =>
        Supabase.instance.client.functions.invoke(functionName, body: body),
  ),
);

PlaceFunctionInvoker buildPlaceFunctionInvoker({
  required SupabasePlaceFunctionCall call,
}) {
  return (action, body) async {
    try {
      final response = await call(
        'places-proxy',
        body: {'action': action, ...body},
      );
      if (response.status < 200 || response.status >= 300) {
        throw _exceptionForResponse(response.status, response.data);
      }
      if (response.data is! Map) {
        throw const PlaceSearchException(
          'The place service returned an invalid response.',
          code: 'invalid_response',
        );
      }
      try {
        return Map<String, dynamic>.from(response.data as Map);
      } catch (_) {
        throw const PlaceSearchException(
          'The place service returned an invalid response.',
          code: 'invalid_response',
        );
      }
    } on PlaceSearchException {
      rethrow;
    } on FunctionException catch (error) {
      throw _exceptionForResponse(error.status, error.details);
    } on TimeoutException {
      throw const PlaceSearchException(
        'Place lookup timed out. Please try again.',
        code: 'timeout',
      );
    } catch (_) {
      throw const PlaceSearchException(
        'Place search is temporarily unavailable. Please try again.',
        code: 'provider_error',
      );
    }
  };
}

PlaceSearchException _exceptionForResponse(int status, Object? data) {
  final responseCode = _responseErrorCode(data);
  final code = switch (responseCode) {
    'unauthorized' ||
    'invalid_request' ||
    'rate_limited' ||
    'timeout' ||
    'provider_error' ||
    'internal_error' => responseCode!,
    _ => switch (status) {
      400 => 'invalid_request',
      401 || 403 => 'unauthorized',
      429 => 'rate_limited',
      408 || 504 => 'timeout',
      500 || 503 => 'internal_error',
      _ => 'provider_error',
    },
  };

  final message = switch (code) {
    'invalid_request' => 'The place request is invalid.',
    'unauthorized' => 'Please sign in to search for places.',
    'rate_limited' => 'Too many place requests. Please wait and try again.',
    'timeout' => 'Place lookup timed out. Please try again.',
    'internal_error' =>
      'The place service is temporarily unavailable. Please try again.',
    _ => 'Place search is temporarily unavailable. Please try again.',
  };
  return PlaceSearchException(message, code: code);
}

String? _responseErrorCode(Object? data) {
  if (data is! Map) return null;
  final error = data['error'];
  if (error is! Map) return null;
  final code = error['code'];
  return code is String ? code : null;
}

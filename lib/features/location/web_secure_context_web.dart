import 'dart:js_interop';

@JS('globalThis.isSecureContext')
external bool get _isSecureContext;

bool isWebSecureContext() => _isSecureContext;

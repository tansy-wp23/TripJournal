import 'dart:js_interop';

@JS('tripJournalGoogleMapsSdkState')
external JSString? get _tripJournalGoogleMapsSdkState;

bool get isGoogleMapsWebSdkReady =>
    _tripJournalGoogleMapsSdkState?.toDart == 'ready';

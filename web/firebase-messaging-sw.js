// Background push on the web.
//
// firebase_messaging registers this file by name, from the site root, the first
// time a token is asked for; without it getToken() fails on the web and
// PushService logs "start failed". It runs with no Flutter and no Dart, so it
// cannot read lib/firebase_options.dart and carries its own copy of the web app's
// config.
//
// FILL IN after `flutterfire configure` has registered the web app: copy apiKey
// and appId from the `web` block of lib/firebase_options.dart. Until then the
// service worker fails to start, which leaves the web exactly as it was
// before: running, with push off.
//
// The SDK version matches firebase_core_web's supportedFirebaseJsSdkVersion.
// Raise both together.

importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'FILL_IN_FROM_firebase_options.dart',
  appId: 'FILL_IN_FROM_firebase_options.dart',
  messagingSenderId: '1011991713307',
  projectId: 'hajjoperations',
  authDomain: 'hajjoperations.firebaseapp.com',
  storageBucket: 'hajjoperations.firebasestorage.app',
});

// Constructed for its side effect: a message carrying a `notification` block
// is shown by the browser while the tab is closed or hidden. Data-only
// messages are not shown — the same as on the phones.
firebase.messaging();

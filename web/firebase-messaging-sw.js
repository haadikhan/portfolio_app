// Firebase Cloud Messaging service worker for Flutter web.
// Keep firebaseConfig in sync with `DefaultFirebaseOptions.web` in lib/firebase_options.dart.
importScripts('https://www.gstatic.com/firebasejs/11.0.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.0.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB5NZy3uBv2gqZsSJj-3zcQx_HEVzreWjo',
  appId: '1:500864820062:web:2c437a4bea2a0c01f8e5cf',
  messagingSenderId: '500864820062',
  projectId: 'portfolio-e97b1',
  authDomain: 'portfolio-e97b1.firebaseapp.com',
  storageBucket: 'portfolio-e97b1.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] background message', payload);
});

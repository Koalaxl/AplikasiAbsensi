// Firebase Messaging Service Worker
// Wajib ada di root folder web/ (sejajar dengan index.html)

importScripts("https://www.gstatic.com/firebasejs/10.13.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.1/firebase-messaging-compat.js");

// Config diambil dari lib/firebase_options.dart -> FirebaseOptions web
firebase.initializeApp({
  apiKey: "AIzaSyC1MMr4lN3CDDZPW68NSndXJnYC1ZJsbCc",
  appId: "1:911429912004:web:225a78890a963850671091",
  messagingSenderId: "911429912004",
  projectId: "absensi-sekolah-47534",
  authDomain: "absensi-sekolah-47534.firebaseapp.com",
  storageBucket: "absensi-sekolah-47534.firebasestorage.app",
  measurementId: "G-634JE5F85Z",
});

const messaging = firebase.messaging();

// Handle notifikasi saat tab browser di-background / ditutup
messaging.onBackgroundMessage((payload) => {
  console.log("Menerima pesan background:", payload);

  const notificationTitle = payload.notification?.title ?? "Notifikasi";
  const notificationOptions = {
    body: payload.notification?.body ?? "",
    icon: "/icons/Icon-192.png",
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
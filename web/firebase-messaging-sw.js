// GroWell — service worker push notification web (PRD F8).
// Konfigurasi Firebase dibuat oleh demo.ps1 dari firebase_config.json ke web/firebase-config.js
// (diabaikan git). Tanpa berkas itu service worker tidak melakukan apa-apa.
try {
  importScripts('firebase-config.js');
} catch (e) {
  self.GROWELL_FIREBASE = null;
}

if (self.GROWELL_FIREBASE) {
  importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
  importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');
  firebase.initializeApp(self.GROWELL_FIREBASE);
  const messaging = firebase.messaging();
  // Notifikasi saat aplikasi tertutup/di latar belakang.
  messaging.onBackgroundMessage((payload) => {
    if (payload.notification) return; // sudah ditampilkan otomatis oleh FCM
    const d = payload.data || {};
    self.registration.showNotification(d.title || 'GroWell', { body: d.body || '', icon: 'icons/Icon-192.png', data: d });
  });
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = (event.notification.data && (event.notification.data.route || (event.notification.data.FCM_MSG && event.notification.data.FCM_MSG.data && event.notification.data.FCM_MSG.data.route))) || '/app';
  event.waitUntil(clients.openWindow('./#' + route));
});

importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDijfkVxpzBd2yYlkEpbz7xdx4A2gfkmfw',
  authDomain: 'senada-app.firebaseapp.com',
  projectId: 'senada-app',
  storageBucket: 'senada-app.firebasestorage.app',
  messagingSenderId: '746938916742',
  appId: '1:746938916742:web:c65a7ce6ff1269f2e2d607',
  measurementId: 'G-L9CRSCVMPK'
});

const messaging = firebase.messaging();
messaging.onBackgroundMessage((payload) => {
  // FCM menampilkan payload notification secara otomatis di background.
  // Tampilkan manual hanya untuk pesan data-only agar tidak muncul dua kali.
  if (payload.notification) return;
  const data = payload.data || {};
  self.registration.showNotification(data.title || 'SENADA', {
    body: data.body || 'Anda memiliki notifikasi baru.',
    icon: '/icons/Icon-192.png',
    data
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow('/'));
});

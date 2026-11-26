importScripts(
  'https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js'
);

importScripts(
  'https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js'
);

firebase.initializeApp({
  apiKey: 'AIzaSyDDFjJ9QG8uikqozLwP7RzPg66g32rOsXo',
  authDomain: 'udes-54aad.firebaseapp.com',
  projectId: 'udes-54aad',
  storageBucket: 'udes-54aad.firebasestorage.app',
  messagingSenderId: '1047197774233',
  appId: '1:1047197774233:web:ce95558cb3615bfdb6a308'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Background FCM message:', payload);

  const title = payload.notification?.title ?? 'UniGrades';
  const body = payload.notification?.body ?? 'Проверете оценките си.';

  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'unigrades-notification',
    data: {
      url: '/'
    }
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  event.waitUntil(
    clients.matchAll({
      type: 'window',
      includeUncontrolled: true
    }).then((openClients) => {
      const existing = openClients.find(
        (client) => client.url.startsWith(self.location.origin)
      );

      return existing
        ? existing.focus()
        : clients.openWindow('/');
    })
  );
});
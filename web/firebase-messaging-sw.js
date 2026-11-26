importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDDFjJ9QG8uikqozLwP7RzPg66g32rOsXo',
  authDomain: 'udes-54aad.firebaseapp.com',
  projectId: 'udes-54aad',
  storageBucket: 'udes-54aad.firebasestorage.app',
  messagingSenderId: '1047197774233',
  appId: '1:1047197774233:web:ce95558cb3615bfdb6a308'
});

const messaging = firebase.messaging();

// Same value as TuApiService.webApiBaseUrl. Must be public HTTPS in production.
const BACKEND_URL = 'http://localhost:3000';
const FCM_SERVER = 'https://unigrades.bgsrv.eu';

function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open('unigrades', 1);
    req.onupgradeneeded = () => {
      if (!req.result.objectStoreNames.contains('credentials')) {
        req.result.createObjectStore('credentials');
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function idbGet(key) {
  const db = await openDb();
  return new Promise((resolve) => {
    const r = db.transaction('credentials', 'readonly').objectStore('credentials').get(key);
    r.onsuccess = () => resolve(r.result);
    r.onerror = () => resolve(undefined);
  });
}

async function idbSet(key, value) {
  const db = await openDb();
  return new Promise((resolve) => {
    const tx = db.transaction('credentials', 'readwrite');
    tx.objectStore('credentials').put(value, key);
    tx.oncomplete = () => resolve();
    tx.onerror = () => resolve();
  });
}

async function num(key, fallback) {
  const v = parseInt((await idbGet(key)) ?? '', 10);
  return Number.isNaN(v) ? fallback : v;
}

async function ack(jobId, fcmToken, status, info) {
  if (!jobId) return;
  try {
    await fetch(`${FCM_SERVER}/ack`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jobId, fcmToken: fcmToken || '', status, info })
    });
  } catch (e) {
    console.error('ACK failed', e);
  }
}

let shown = false;

async function notify(title, options) {
  shown = true;
  return self.registration.showNotification(title, options);
}

async function quietNotice() {
  await self.registration.showNotification('UniGrades', {
    body: 'Проверка на оценките...',
    icon: '/icons/Icon-192.png',
    tag: 'unigrades-quiet',
    silent: true
  });
  await new Promise((r) => setTimeout(r, 1500));
  const list = await self.registration.getNotifications({ tag: 'unigrades-quiet' });
  list.forEach((n) => n.close());
}

async function runGradeCheck(jobId) {
  const fnum = await idbGet('fnum');
  const egn = await idbGet('egn');
  const token = (await idbGet('fcm_token')) || '';
  const mode = (await idbGet('notification_mode')) || 'all_notifications';

  if (!fnum || !egn) return ack(jobId, token, 'skipped', 'missing_credentials');

  const interval = await num('interval', 30);
  const required = interval <= 30 ? 1 : Math.round(interval / 30);
  const wake = (await num('wake_counter', 0)) + 1;
  if (wake < required) {
    await idbSet('wake_counter', String(wake));
    return ack(jobId, token, 'waiting', `remaining_wakes:${required - wake}`);
  }
  await idbSet('wake_counter', '0');

  try {
    const res = await fetch(`${BACKEND_URL}/api/tu/grades`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fnum, egn, deistvie: '1' })
    });
    if (!res.ok) throw new Error('HTTP ' + res.status);

    const html = await res.text();
    // Latin o or Cyrillic о, then "ценк", then а or и (same pattern Android counts)
    const count = (html.match(/[o\u043E]\u0446\u0435\u043D\u043A[\u0430\u0438]/gi) || []).length;
    const last = await num('last_count', -1);
    await idbSet('last_count', String(count));

    if (last === -1) {
      if (mode === 'all_notifications') {
        await notify('✅ Активно следене', {
          body: `Първа проверка | Оценки: ${count}`,
          icon: '/icons/Icon-192.png',
          badge: '/icons/Icon-192.png',
          tag: 'unigrades-status'
        });
      }
      return ack(jobId, token, 'initialized', 'first_check');
    }

    if (count > last) {
      const diff = count - last;
      await notify('🎓 Нова оценка!', {
        body: diff === 1
          ? 'Получихте нова оценка в e-university!'
          : `Получихте ${diff} нови оценки в e-university!`,
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        tag: 'unigrades-new-grade',
        renotify: true,
        data: { url: '/' }
      });
      return ack(jobId, token, 'new_grade', `new_grades:${diff}`);
    }

    if (mode === 'all_notifications') {
      await notify('✅ Няма промяна', {
        body: `Оценки: ${count} | ${new Date().toLocaleTimeString('bg-BG')}`,
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        tag: 'unigrades-status'
      });
    }
    return ack(jobId, token, 'no_change', `count:${count}`);
  } catch (e) {
    return ack(jobId, token, 'error', String(e));
  }
}

messaging.onBackgroundMessage(async (payload) => {
  const data = payload.data || {};
  if (data.type === 'check_grades') {
    shown = false;
    await runGradeCheck(data.jobId);
    if (!shown) await quietNotice();
  }
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      const existing = list.find((c) => c.url.startsWith(self.location.origin));
      return existing ? existing.focus() : clients.openWindow('/');
    })
  );
});
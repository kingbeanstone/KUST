importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

// 💡 사용자님의 Firebase 설정값 적용
firebase.initializeApp({
  apiKey: "AIzaSyAZnDCZeKVdUBC1eM6e6X-tYvUXZz6kUfU",
  authDomain: "kust-88683.firebaseapp.com",
  projectId: "kust-88683",
  storageBucket: "kust-88683.firebasestorage.app",
  messagingSenderId: "320857165783",
  appId: "1:320857165783:web:1094126f5f522b90938592"
});


const messaging = firebase.messaging();

// 백그라운드 메시지 처리
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] 백그라운드 메시지 수신: ', payload);

  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
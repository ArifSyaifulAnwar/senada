import 'package:firebase_core/firebase_core.dart';

/// Konfigurasi publik Firebase untuk aplikasi Web SENADA.
abstract final class FirebaseWebOptions {
  static const FirebaseOptions current = FirebaseOptions(
    apiKey: 'AIzaSyDijfkVxpzBd2yYlkEpbz7xdx4A2gfkmfw',
    authDomain: 'senada-app.firebaseapp.com',
    projectId: 'senada-app',
    storageBucket: 'senada-app.firebasestorage.app',
    messagingSenderId: '746938916742',
    appId: '1:746938916742:web:c65a7ce6ff1269f2e2d607',
    measurementId: 'G-L9CRSCVMPK',
  );
}

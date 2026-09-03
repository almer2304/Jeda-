# Prompt untuk Fase Berikutnya

**Fase 5: Build & Deploy**

```text
Lanjutkan ke Fase 5: Build & Deploy untuk Jeda (MindfulLock).

SPESIFIKASI:
1. Ganti nama aplikasi secara menyeluruh menjadi "Jeda":
   - Update `android:label="MindfulLock"` menjadi `android:label="Jeda"` di `android/app/src/main/AndroidManifest.xml`.
   - Update nama app di material app `lib/main.dart`.
2. Hapus seluruh kode `print()` atau `debugPrint()` dari aplikasi untuk keamanan di production.
3. Berikan instruksi build APK mode Release ke pengguna:
   - `flutter build apk --release`
   - Berikan arahan bagaimana pengguna bisa menemukannya di folder output dan memindahkannya ke HP jika diperlukan.
4. Lakukan final update di `PROJECT_STATE.md` menjadi selesai seluruhnya.
```
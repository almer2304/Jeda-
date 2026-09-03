# MindfulLock (Jeda) — Progress & Checkpoint

## Apa yang Telah Kita Capai Sejauh Ini?

Kita telah menyelesaikan fondasi utama dari aplikasi Jeda (Fase 0 hingga 3). Berikut adalah ringkasannya:

1.  **Fase 0: Inisialisasi Proyek**
    *   Kerangka Flutter dan konfigurasi Gradle/Android selesai (SDK Min 31).
    *   Dependensi krusial seperti Riverpod dan Hive sudah terpasang.
2.  **Fase 1: Models & Storage**
    *   Sistem basis data *offline* (Hive) sudah siap (menyimpan data status aplikasi yang dikunci, durasi, dll).
3.  **Fase 2: Native Kotlin Bridge**
    *   *Service* Android asli sudah dibuat (AppMonitorService, OverlayManager, DNS Filter).
    *   Sistem bisa mengenali aplikasi apa saja yang sedang berjalan di *foreground* HP.
    *   Bug terkait `getInstalledApps` (error parse JSON) sudah kita selesaikan.
4.  **Fase 3: UI Utama (Flutter)**
    *   Layar *Onboarding* untuk meminta izin.
    *   Tombol *Bypass* (Lewati) telah ditambahkan khusus untuk mengakal bug pada itelOS di mana sistem operasi tidak menyediakan *toggle* untuk Akses Penggunaan.
    *   Layar `DashboardScreen` untuk melihat aplikasi yang sedang dikunci, lengkap dengan UI penghematan waktu.
    *   Layar `AddLockScreen` dengan fungsi cari (Search), penggeser waktu, dan daftar aplikasi.

---

## Apa yang Harus Anda (User) Lakukan & Pastikan Sekarang?

Sebelum kita melompat ke Fase 4, Anda perlu menguji jalannya UI di HP Anda secara langsung. Pastikan Anda sudah membuka aplikasi Jeda di layar HP. 

Lakukan **Checklist Pengujian** berikut:

### 1. Uji Onboarding & Layar Utama
- [ ] Di layar yang meminta izin (Onboarding), klik **Lewati** (Skip) untuk Step 1 dan Step 2.
- [ ] Klik **Lewati** atau **Izinkan** untuk Step 3 (Baterai).
- [ ] Anda seharusnya berhasil masuk ke layar utama (Dashboard). Pastikan layarnya berwarna dominan krem dengan teks berwarna *sage green*, tanpa error.

### 2. Uji Layar "Tambah Fokus" (Add Lock)
- [ ] Di Dashboard, klik tombol melayang **"Fokus Baru" (+)** di pojok kanan bawah.
- [ ] Pastikan Anda masuk ke layar `Pilih App & Durasi`.
- [ ] **Pastikan daftar aplikasi HP Anda muncul** (bisa di-scroll).
- [ ] Coba ketik di kotak pencarian (misal: "Instagram" atau "Tiktok"). Apakah daftarnya ter-filter dengan benar?
- [ ] Geser *slider* waktu di bagian bawah (dari 1 jam ke angka lain). Apakah teks perkiraan jam selesai-nya berubah secara akurat?

### 3. Uji Pembuatan & Penghapusan Sesi Fokus
- [ ] Pilih salah satu aplikasi bebas dari daftar.
- [ ] Tekan tombol **Mulai Fokus 🌱**.
- [ ] Anda seharusnya dikembalikan ke Dashboard.
- [ ] Pastikan aplikasi yang baru saja Anda pilih muncul di daftar "Sedang Dikunci" di Dashboard, lengkap dengan *timer* mundur (contoh: `01:00:00` berjalan mundur).
- [ ] Coba geser (*swipe*) ke arah kiri pada kartu aplikasi yang sedang dikunci tersebut.
- [ ] Pastikan muncul kotak dialog peringatan *"Kamu yakin ingin membuka kunci lebih awal?"*.
- [ ] Tekan **Hentikan** (tombol merah) dan pastikan aplikasi tersebut hilang dari layar Dashboard.

---

## Catatan Khusus untuk itelOS (Device Anda)
*   **Akses Penggunaan**: Karena itelOS memblokir jalur pintas kita untuk izin "Usage Access", saat ini fitur memunculkan layar hitam saat aplikasi terlarang dibuka **belum aktif seutuhnya** secara latar belakang. Tujuan saat ini (Fase 3) adalah memastikan UI/desain visual dan logikanya tidak *crash*. Perbaikan sistem pengunciannya akan ditinjau kembali bersamaan dengan implementasi VPN web filter di Fase 4.

**Langkah selanjutnya:**
Beri tahu saya jika checklist 1, 2, dan 3 di atas sudah berfungsi lancar. Jika sudah, kita bisa melangkah menggunakan prompt **Fase 4: Edukasi & Web Filter** yang ada di `PROJECT_PROMPTS.md`.
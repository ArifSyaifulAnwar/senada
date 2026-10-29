/*
  SENADA - Keep-login rolling session

  Jalankan setelah 041. Sesi aktif diperpanjang sampai satu tahun dari
  sekarang. Setiap refresh token berikutnya memperpanjang lagi satu tahun,
  sehingga user aktif tetap login sampai menekan Keluar.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF OBJECT_ID('dbo.udt_user_refresh_session', 'U') IS NULL
    THROW 54300, 'Tabel sesi refresh belum ada. Jalankan migration 041 terlebih dahulu.', 1;
GO

UPDATE s
SET expires_at = DATEADD(DAY, 365, SYSUTCDATETIME())
FROM dbo.udt_user_refresh_session s
INNER JOIN dbo.udt_users u ON u.userid = s.userid
WHERE s.revoked_at IS NULL
  AND u.active = 1
  AND ISNULL(u.deleted, 0) = 0;
GO

SELECT COUNT(*) AS active_keep_login_sessions,
       MIN(expires_at) AS nearest_expiry_utc,
       MAX(expires_at) AS latest_expiry_utc
FROM dbo.udt_user_refresh_session
WHERE revoked_at IS NULL;
GO

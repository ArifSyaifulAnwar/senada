/*
  SENADA - Reset password untuk akun yang terkunci otomatis

  Aturan:
  - Akun aktif dapat meminta reset password.
  - Akun yang terkunci karena wrong_login >= 3 dapat meminta reset password.
  - Akun yang dihapus atau dinonaktifkan HRD (active = 0, wrong_login < 3)
    tetap tidak dapat memulihkan dirinya sendiri.
  - Akun baru diaktifkan kembali setelah OTP benar dan password berhasil diganti.
*/

USE [ABSENSI];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.udp_app_save_otp
    @UserEmail NVARCHAR(255),
    @OtpCode   NVARCHAR(6),
    @Expiry    DATETIME
AS
BEGIN
    /*
      Jangan gunakan SET NOCOUNT ON di procedure ini. API lama menentukan
      keberhasilan melalui jumlah baris dari ExecuteNonQueryAsync().
    */
    SET XACT_ABORT ON;

    SET @UserEmail = NULLIF(LOWER(LTRIM(RTRIM(@UserEmail))), '');
    SET @OtpCode = NULLIF(LTRIM(RTRIM(@OtpCode)), '');

    IF @UserEmail IS NULL OR @OtpCode IS NULL OR LEN(@OtpCode) <> 6
       OR @Expiry IS NULL
        THROW 50200, 'Data permintaan OTP tidak valid.', 1;

    UPDATE dbo.udt_users
    SET
        otp = @OtpCode,
        otp_expiry = @Expiry,
        otp_verified = 0,
        updated_at = GETUTCDATE()
    WHERE LOWER(LTRIM(RTRIM(mail))) = @UserEmail
      AND ISNULL(deleted, 0) = 0
      AND
      (
          active = 1
          OR ISNULL(wrong_login, 0) >= 3
      );
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_app_reset_password
    @UserEmail  NVARCHAR(255),
    @OtpCode    NVARCHAR(6),
    @NewPassword NVARCHAR(MAX),
    @ResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @ResultCode = 0;
    SET @UserEmail = NULLIF(LOWER(LTRIM(RTRIM(@UserEmail))), '');
    SET @OtpCode = NULLIF(LTRIM(RTRIM(@OtpCode)), '');

    DECLARE
        @StoredOtp VARCHAR(6),
        @OtpExpiry DATETIME,
        @Active BIT,
        @Deleted BIT,
        @WrongLogin INT;

    SELECT TOP (1)
        @StoredOtp = otp,
        @OtpExpiry = otp_expiry,
        @Active = active,
        @Deleted = deleted,
        @WrongLogin = ISNULL(wrong_login, 0)
    FROM dbo.udt_users
    WHERE LOWER(LTRIM(RTRIM(mail))) = @UserEmail;

    /* Tidak ditemukan, dihapus, atau sengaja dinonaktifkan HRD. */
    IF @Deleted IS NULL
       OR @Deleted = 1
       OR (ISNULL(@Active, 0) = 0 AND ISNULL(@WrongLogin, 0) < 3)
    BEGIN
        SET @ResultCode = -1;
        RETURN;
    END;

    IF @StoredOtp IS NULL
       OR @OtpCode IS NULL
       OR @StoredOtp <> @OtpCode
       OR @OtpExpiry IS NULL
       OR @OtpExpiry < GETUTCDATE()
    BEGIN
        SET @ResultCode = -2;
        RETURN;
    END;

    IF NULLIF(@NewPassword, N'') IS NULL
    BEGIN
        SET @ResultCode = -3;
        RETURN;
    END;

    UPDATE dbo.udt_users
    SET
        pw = HASHBYTES('SHA2_256', CONVERT(VARCHAR(255), @NewPassword)),
        otp = NULL,
        otp_expiry = NULL,
        otp_verified = 1,
        wrong_login = 0,
        active = 1,
        updateby = 'SYSTEM_PASSWORD_RESET',
        updated_at = GETUTCDATE()
    WHERE LOWER(LTRIM(RTRIM(mail))) = @UserEmail
      AND ISNULL(deleted, 0) = 0
      AND
      (
          active = 1
          OR ISNULL(wrong_login, 0) >= 3
      );

    IF @@ROWCOUNT = 1
        SET @ResultCode = 1;
    ELSE
        SET @ResultCode = 0;
END;
GO

SELECT
    p.name AS procedure_name,
    p.modify_date
FROM sys.procedures p
WHERE p.name IN ('udp_app_save_otp', 'udp_app_reset_password')
ORDER BY p.name;
GO

/* Pemeriksaan khusus akun Daniel tanpa menampilkan password atau OTP. */
SELECT
    userid,
    name,
    mail,
    wrong_login,
    active,
    deleted,
    otp_expiry
FROM dbo.udt_users
WHERE userid = '032601';
GO

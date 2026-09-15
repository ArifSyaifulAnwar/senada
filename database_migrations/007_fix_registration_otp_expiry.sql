/*
  SENADA - Sinkronisasi masa berlaku OTP registrasi

  API server pernah tertinggal beberapa menit dari SQL Server. Karena itu
  @OTPExpiry dari API tidak dipakai sebagai waktu absolut. Durasi OTP tetap
  lima menit, tetapi dihitung dari GETUTCDATE() milik database.
*/

USE [ABSENSI];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.udp_register_initiate
    @UserId         VARCHAR(50),
    @Name           VARCHAR(100),
    @Password       VARCHAR(255),
    @Email          VARCHAR(255),
    @Phone          VARCHAR(20) = NULL,
    @OTP            VARCHAR(6),
    @OTPExpiry      DATETIME,
    @InviteCode     VARCHAR(12) = NULL,
    @NewCompanyName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @UserId = NULLIF(LTRIM(RTRIM(@UserId)), '');
    SET @Name = NULLIF(LTRIM(RTRIM(@Name)), '');
    SET @Email = NULLIF(LOWER(LTRIM(RTRIM(@Email))), '');
    SET @Phone = NULLIF(LTRIM(RTRIM(@Phone)), '');
    SET @OTP = NULLIF(LTRIM(RTRIM(@OTP)), '');
    SET @InviteCode = NULLIF(UPPER(LTRIM(RTRIM(@InviteCode))), '');
    SET @NewCompanyName = NULLIF(LTRIM(RTRIM(@NewCompanyName)), N'');

    IF @UserId IS NULL OR @Name IS NULL OR @Email IS NULL
       OR NULLIF(@Password, '') IS NULL OR @OTP IS NULL
        THROW 50300, 'Data registrasi belum lengkap.', 1;

    IF LEN(@OTP) <> 6
        THROW 50301, 'Format OTP tidak valid.', 1;

    IF (@InviteCode IS NULL AND @NewCompanyName IS NULL)
       OR (@InviteCode IS NOT NULL AND @NewCompanyName IS NOT NULL)
        THROW 50302, 'Isi salah satu: kode undangan atau nama perusahaan baru.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.udt_users
        WHERE LOWER(LTRIM(RTRIM(mail))) = @Email
          AND ISNULL(deleted, 0) = 0
    )
        THROW 50303, 'Email sudah terdaftar.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.udt_users
        WHERE userid = @UserId
          AND ISNULL(deleted, 0) = 0
    )
        THROW 50304, 'User ID sudah terdaftar.', 1;

    IF @InviteCode IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.udt_companies
           WHERE UPPER(LTRIM(RTRIM(invite_code))) = @InviteCode
             AND is_active = 1
       )
        THROW 50305, 'Kode undangan tidak valid atau perusahaan tidak aktif.', 1;

    IF @NewCompanyName IS NOT NULL
       AND EXISTS
       (
           SELECT 1
           FROM dbo.udt_companies
           WHERE LOWER(LTRIM(RTRIM(company_name))) = LOWER(@NewCompanyName)
       )
        THROW 50306, 'Nama perusahaan sudah terdaftar.', 1;

    DECLARE @Role VARCHAR(50) =
        CASE WHEN @NewCompanyName IS NULL THEN 'User' ELSE 'HRD' END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.udt_registration_temp
        WHERE LOWER(LTRIM(RTRIM(email))) = @Email;

        INSERT INTO dbo.udt_registration_temp
        (
            user_id, name, password, email, phone,
            otp, otp_expiry, role, created_at,
            invite_code, new_company_name
        )
        VALUES
        (
            @UserId, @Name, HASHBYTES('SHA2_256', @Password), @Email, @Phone,
            @OTP, DATEADD(MINUTE, 5, GETUTCDATE()), @Role, GETUTCDATE(),
            @InviteCode, @NewCompanyName
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

SELECT
    p.name AS procedure_name,
    p.modify_date
FROM sys.procedures p
WHERE p.name = 'udp_register_initiate';
GO


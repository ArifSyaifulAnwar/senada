/*
  SENADA - Registrasi publik multi-perusahaan

  Aturan bisnis:
  1. Satu akun hanya boleh menjadi anggota satu perusahaan.
  2. Pendaftar perusahaan baru menjadi Head HRD perusahaan tersebut.
  3. Perusahaan baru memperoleh kode undangan unik.
  4. Pendaftar dengan kode undangan otomatis dipetakan ke company_id pemilik kode.
  5. Nama perusahaan dan kode undangan tidak ditentukan dari Flutter saat OTP
     diverifikasi; database membaca data registrasi sementara yang tervalidasi.
  6. Pembuatan perusahaan, user, dan mapping perusahaan berlangsung dalam satu
     transaksi agar tidak pernah terbentuk data setengah jadi.

  Jalankan pada database ABSENSI, lalu deploy API terbaru.
*/

USE [ABSENSI];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* Kode undangan harus unik lintas seluruh perusahaan. */
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.udt_companies')
      AND name = N'UX_udt_companies_invite_code'
)
BEGIN
    IF EXISTS
    (
        SELECT UPPER(LTRIM(RTRIM(invite_code)))
        FROM dbo.udt_companies
        WHERE NULLIF(LTRIM(RTRIM(invite_code)), '') IS NOT NULL
        GROUP BY UPPER(LTRIM(RTRIM(invite_code)))
        HAVING COUNT(*) > 1
    )
        THROW 50900, 'Kode undangan perusahaan masih duplikat. Rapikan data sebelum membuat index.', 1;

    CREATE UNIQUE INDEX UX_udt_companies_invite_code
        ON dbo.udt_companies(invite_code)
        WHERE invite_code IS NOT NULL;
END;
GO

/* Satu user hanya boleh memiliki satu mapping perusahaan. */
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.udt_company_info_user')
      AND name = N'UX_udt_company_info_user_userid'
)
BEGIN
    IF EXISTS
    (
        SELECT userid
        FROM dbo.udt_company_info_user
        GROUP BY userid
        HAVING COUNT(*) > 1
    )
        THROW 50901, 'Ada user yang terhubung ke lebih dari satu perusahaan.', 1;

    CREATE UNIQUE INDEX UX_udt_company_info_user_userid
        ON dbo.udt_company_info_user(userid);
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_company_validate_invite
    @InviteCode VARCHAR(12)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1) c.company_name
    FROM dbo.udt_companies c
    WHERE UPPER(LTRIM(RTRIM(c.invite_code))) =
          UPPER(LTRIM(RTRIM(@InviteCode)))
      AND c.is_active = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_company_name_exists
    @CompanyName NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.udt_companies
        WHERE LOWER(LTRIM(RTRIM(company_name))) =
              LOWER(LTRIM(RTRIM(@CompanyName)))
    ) THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_get_company_invite_code
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        c.company_name,
        c.invite_code
    FROM dbo.udt_company_info_user ci
    INNER JOIN dbo.udt_companies c
        ON c.id = ci.company_id
       AND c.is_active = 1
    INNER JOIN dbo.udt_users u
        ON u.userid = ci.userid
       AND u.active = 1
       AND ISNULL(u.deleted, 0) = 0
    WHERE ci.userid = @UserId;
END;
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
        THROW 50910, 'Data registrasi belum lengkap.', 1;

    IF LEN(@OTP) <> 6 OR @OTP LIKE '%[^0-9]%'
        THROW 50911, 'Format OTP tidak valid.', 1;

    IF (@InviteCode IS NULL AND @NewCompanyName IS NULL)
       OR (@InviteCode IS NOT NULL AND @NewCompanyName IS NOT NULL)
        THROW 50912, 'Pilih gabung perusahaan atau daftarkan perusahaan baru.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.udt_users
        WHERE LOWER(LTRIM(RTRIM(mail))) = @Email
          AND ISNULL(deleted, 0) = 0
    )
        THROW 50913, 'Email sudah terdaftar.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.udt_users
        WHERE userid = @UserId AND ISNULL(deleted, 0) = 0
    )
        THROW 50914, 'User ID sudah terdaftar.', 1;

    IF @InviteCode IS NOT NULL AND NOT EXISTS
    (
        SELECT 1 FROM dbo.udt_companies
        WHERE UPPER(LTRIM(RTRIM(invite_code))) = @InviteCode
          AND is_active = 1
    )
        THROW 50915, 'Kode undangan tidak valid atau perusahaan tidak aktif.', 1;

    IF @NewCompanyName IS NOT NULL AND EXISTS
    (
        SELECT 1 FROM dbo.udt_companies
        WHERE LOWER(LTRIM(RTRIM(company_name))) = LOWER(@NewCompanyName)
    )
        THROW 50916, 'Nama perusahaan sudah terdaftar.', 1;

    BEGIN TRANSACTION;
    BEGIN TRY
        /* Request ulang mengganti OTP lama, bukan mengunci email. */
        DELETE FROM dbo.udt_registration_temp
        WHERE LOWER(LTRIM(RTRIM(email))) = @Email;

        INSERT INTO dbo.udt_registration_temp
        (
            user_id, name, password, email, phone, otp, otp_expiry,
            role, created_at, invite_code, new_company_name
        )
        VALUES
        (
            @UserId, @Name, HASHBYTES('SHA2_256', @Password), @Email, @Phone,
            @OTP, DATEADD(MINUTE, 5, GETUTCDATE()),
            CASE WHEN @NewCompanyName IS NULL THEN 'User' ELSE 'HRD' END,
            GETUTCDATE(), @InviteCode, @NewCompanyName
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_verify_otp_and_register
    @Email   VARCHAR(255),
    @OTPCode VARCHAR(6),
    @Result  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Result = -5;
    SET @Email = NULLIF(LOWER(LTRIM(RTRIM(@Email))), '');
    SET @OTPCode = NULLIF(LTRIM(RTRIM(@OTPCode)), '');

    DECLARE
        @RegistrationId INT,
        @StoredOtp VARCHAR(6),
        @OtpExpiry DATETIME,
        @UserId VARCHAR(50),
        @Name VARCHAR(100),
        @PasswordHash VARBINARY(255),
        @Phone VARCHAR(20),
        @InviteCode VARCHAR(12),
        @NewCompanyName NVARCHAR(200),
        @CompanyId INT,
        @CompanyName NVARCHAR(200),
        @NewInviteCode VARCHAR(12),
        @IsFounder BIT = 0;

    SELECT TOP (1)
        @RegistrationId = ID,
        @StoredOtp = otp,
        @OtpExpiry = otp_expiry,
        @UserId = user_id,
        @Name = name,
        @PasswordHash = password,
        @Phone = phone,
        @InviteCode = NULLIF(UPPER(LTRIM(RTRIM(invite_code))), ''),
        @NewCompanyName = NULLIF(LTRIM(RTRIM(new_company_name)), N'')
    FROM dbo.udt_registration_temp
    WHERE LOWER(LTRIM(RTRIM(email))) = @Email
    ORDER BY ID DESC;

    IF @RegistrationId IS NULL BEGIN SET @Result = -3; RETURN; END;
    IF @OtpExpiry IS NULL OR @OtpExpiry < GETUTCDATE()
    BEGIN
        DELETE FROM dbo.udt_registration_temp WHERE ID = @RegistrationId;
        SET @Result = -1;
        RETURN;
    END;
    IF @StoredOtp <> @OTPCode BEGIN SET @Result = -2; RETURN; END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS
        (
            SELECT 1 FROM dbo.udt_users WITH (UPDLOCK, HOLDLOCK)
            WHERE (LOWER(LTRIM(RTRIM(mail))) = @Email OR userid = @UserId)
              AND ISNULL(deleted, 0) = 0
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SET @Result = -4;
            RETURN;
        END;

        IF @InviteCode IS NOT NULL
        BEGIN
            SELECT TOP (1)
                @CompanyId = id,
                @CompanyName = company_name
            FROM dbo.udt_companies WITH (UPDLOCK, HOLDLOCK)
            WHERE UPPER(LTRIM(RTRIM(invite_code))) = @InviteCode
              AND is_active = 1;

            IF @CompanyId IS NULL
            BEGIN
                ROLLBACK TRANSACTION;
                SET @Result = -6;
                RETURN;
            END;
        END
        ELSE IF @NewCompanyName IS NOT NULL
        BEGIN
            IF EXISTS
            (
                SELECT 1 FROM dbo.udt_companies WITH (UPDLOCK, HOLDLOCK)
                WHERE LOWER(LTRIM(RTRIM(company_name))) = LOWER(@NewCompanyName)
            )
            BEGIN
                ROLLBACK TRANSACTION;
                SET @Result = -7;
                RETURN;
            END;

            SET @IsFounder = 1;
            SET @CompanyName = @NewCompanyName;

            DECLARE @Attempt INT = 0;
            WHILE @Attempt < 50
            BEGIN
                SET @NewInviteCode = 'CMP' + UPPER(LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 9));
                IF NOT EXISTS
                    (SELECT 1 FROM dbo.udt_companies WHERE invite_code = @NewInviteCode)
                    BREAK;
                SET @Attempt += 1;
            END;

            IF @Attempt >= 50 THROW 50920, 'Gagal menghasilkan kode perusahaan unik.', 1;

            INSERT INTO dbo.udt_companies
                (company_name, invite_code, created_by_userid, is_active)
            VALUES
                (@CompanyName, @NewInviteCode, @UserId, 1);

            SET @CompanyId = CONVERT(INT, SCOPE_IDENTITY());
        END
        ELSE
            THROW 50921, 'Tujuan perusahaan registrasi tidak ditemukan.', 1;

        INSERT INTO dbo.udt_users
        (
            userid, name, pw, role, mail, phone, active, deleted,
            wrong_login, createby, created_at, updated_at
        )
        VALUES
        (
            @UserId, @Name, @PasswordHash,
            CASE WHEN @IsFounder = 1 THEN 'HRD' ELSE 'User' END,
            @Email, @Phone, 1, 0, 0,
            'SYSTEM_REGISTRATION', GETUTCDATE(), GETUTCDATE()
        );

        INSERT INTO dbo.udt_company_info_user
        (
            userid, name, mail, employeeID, company_id, company_name,
            organization, job_position, job_level, employment_status,
            join_date, created_at, updated_at
        )
        VALUES
        (
            @UserId, @Name, @Email, @UserId, @CompanyId, @CompanyName,
            CASE WHEN @IsFounder = 1 THEN 'HRD & GA' ELSE NULL END,
            CASE WHEN @IsFounder = 1 THEN 'HEAD OF HRD & GA' ELSE 'KARYAWAN BARU' END,
            CASE WHEN @IsFounder = 1 THEN 'HEAD' ELSE NULL END,
            'Active', CONVERT(DATE, GETDATE()), GETUTCDATE(), GETUTCDATE()
        );

        DELETE FROM dbo.udt_registration_temp WHERE ID = @RegistrationId;

        COMMIT TRANSACTION;
        SET @Result = 1;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Result = -5;
    END CATCH;
END;
GO

/* Verifikasi instalasi dan kondisi mapping aktif. */
SELECT p.name AS procedure_name, p.modify_date
FROM sys.procedures p
WHERE p.name IN
(
    'udp_company_validate_invite',
    'udp_company_name_exists',
    'udp_get_company_invite_code',
    'udp_register_initiate',
    'udp_verify_otp_and_register'
)
ORDER BY p.name;
GO

SELECT c.id, c.company_name, c.invite_code, c.is_active,
       COUNT(ci.userid) AS total_members
FROM dbo.udt_companies c
LEFT JOIN dbo.udt_company_info_user ci ON ci.company_id = c.id
GROUP BY c.id, c.company_name, c.invite_code, c.is_active
ORDER BY c.id;
GO


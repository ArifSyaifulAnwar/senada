/*
  SENADA - Profil pengguna per perusahaan

  Profil pribadi tetap dimiliki oleh satu user, sedangkan informasi pekerjaan
  selalu dibaca dari udt_company_info_user.company_id. Client tidak dapat
  menentukan perusahaan atau membaca profil memakai email pihak lain.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.udp_user_profile_get
    @request_user_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SET @request_user_id = NULLIF(LTRIM(RTRIM(@request_user_id)), '');
    IF @request_user_id IS NULL
        THROW 52600, 'UserId wajib diisi.', 1;

    SELECT TOP (1)
        u.id, u.userid, u.name, u.role, u.mail, u.phone, u.additional_phone,
        u.address, u.citizen_id_address, u.residential_address, u.postal_code,
        u.jobs, u.gender, u.place_of_birth, u.birth_date, u.marital_status,
        u.blood_type, u.religion, u.nik, u.npwp, u.nip, u.passport_number,
        u.passport_expiry, u.FotoProfil,
        ci.company_id, c.company_name, ci.employeeID, ci.barcode, ci.branch,
        ci.organization, ci.job_position, ci.job_level, ci.employment_status,
        ci.join_date, ci.end_contract_date, ci.grade, ci.class,
        ci.approval_line, ci.manager
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
    WHERE u.userid = @request_user_id
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_UpdateUserProfile
    @Email               VARCHAR(255) = NULL,
    @UserId              VARCHAR(50),
    @RequestUserId       VARCHAR(50),
    @Name                NVARCHAR(200),
    @Phone               VARCHAR(20),
    @AdditionalPhone     VARCHAR(20) = NULL,
    @Gender              VARCHAR(20) = NULL,
    @PlaceOfBirth        NVARCHAR(100) = NULL,
    @BirthDate           DATE = NULL,
    @MaritalStatus       NVARCHAR(50) = NULL,
    @BloodType           VARCHAR(5) = NULL,
    @Religion            NVARCHAR(50) = NULL,
    @Address             NVARCHAR(500) = NULL,
    @CitizenIdAddress    NVARCHAR(500) = NULL,
    @ResidentialAddress  NVARCHAR(500) = NULL,
    @PostalCode          VARCHAR(10) = NULL,
    @Jobs                NVARCHAR(100) = NULL,
    @Nik                 VARCHAR(25) = NULL,
    @NPWP                VARCHAR(25) = NULL,
    @PassportNumber      VARCHAR(50) = NULL,
    @PassportExpiry      DATE = NULL,
    @FotoProfil          VARBINARY(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @UserId = NULLIF(LTRIM(RTRIM(@UserId)), '');
    SET @RequestUserId = NULLIF(LTRIM(RTRIM(@RequestUserId)), '');
    SET @Email = NULLIF(LOWER(LTRIM(RTRIM(@Email))), '');

    IF @UserId IS NULL OR @RequestUserId IS NULL OR @UserId <> @RequestUserId
        THROW 52601, 'Profil hanya dapat diubah oleh pemilik akun.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.udt_users u
        INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
        INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
        WHERE u.userid = @UserId AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
          AND (@Email IS NULL OR LOWER(LTRIM(RTRIM(u.mail))) = @Email)
    )
        THROW 52602, 'Akun aktif atau perusahaan pemilik profil tidak ditemukan.', 1;

    UPDATE dbo.udt_users
    SET name = LTRIM(RTRIM(@Name)), phone = @Phone,
        additional_phone = @AdditionalPhone, gender = @Gender,
        place_of_birth = @PlaceOfBirth, birth_date = @BirthDate,
        marital_status = @MaritalStatus, blood_type = @BloodType,
        religion = @Religion, address = @Address,
        citizen_id_address = @CitizenIdAddress,
        residential_address = @ResidentialAddress, postal_code = @PostalCode,
        jobs = @Jobs, nik = @Nik, npwp = @NPWP,
        passport_number = @PassportNumber, passport_expiry = @PassportExpiry,
        FotoProfil = COALESCE(@FotoProfil, FotoProfil), updated_at = GETDATE()
    WHERE userid = @UserId AND active = 1 AND ISNULL(deleted, 0) = 0;

    UPDATE dbo.udt_company_info_user
    SET name = LTRIM(RTRIM(@Name)), updated_at = GETDATE()
    WHERE userid = @UserId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_UpdateUserProfilePhoto
    @UserId        VARCHAR(50),
    @RequestUserId VARCHAR(50),
    @FotoProfil    VARBINARY(MAX),
    @ResultCode    INT OUTPUT,
    @ResultMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @ResultCode = 500;
    SET @ResultMessage = N'Gagal memperbarui foto profil.';
    SET @UserId = NULLIF(LTRIM(RTRIM(@UserId)), '');
    SET @RequestUserId = NULLIF(LTRIM(RTRIM(@RequestUserId)), '');

    IF @UserId IS NULL OR @RequestUserId IS NULL OR @UserId <> @RequestUserId
    BEGIN
        SET @ResultCode = 403;
        SET @ResultMessage = N'Foto profil hanya dapat diubah oleh pemilik akun.';
        RETURN;
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.udt_users u
        INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
        INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
        WHERE u.userid = @UserId AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
    )
    BEGIN
        SET @ResultCode = 404;
        SET @ResultMessage = N'Akun aktif atau perusahaan tidak ditemukan.';
        RETURN;
    END;

    UPDATE dbo.udt_users
    SET FotoProfil = @FotoProfil, updated_at = GETDATE()
    WHERE userid = @UserId;

    SET @ResultCode = 200;
    SET @ResultMessage = N'Foto profil berhasil diperbarui.';
END;
GO

SELECT p.name, p.modify_date
FROM sys.procedures p
WHERE p.name IN ('udp_user_profile_get', 'udp_UpdateUserProfile', 'udp_UpdateUserProfilePhoto')
ORDER BY p.name;
GO

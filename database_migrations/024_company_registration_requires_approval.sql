/*
  SENADA - Onboarding perusahaan baru harus disetujui Platform Admin

  Karyawan: kode undangan + OTP -> akun User aktif pada PT pemilik kode.
  Pendaftar PT baru: OTP -> PT PendingVerification dan akun pendiri belum aktif.
  Hanya Platform Admin dapat menyetujui/menolak perusahaan baru.

  SETUP SEKALI SAJA (jalankan oleh DBA setelah memilih akun pusat):
    UPDATE dbo.udt_users SET is_platform_admin = 1 WHERE userid = '<USER_ID_ADMIN_PUSAT>';
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.udt_companies', 'registration_status') IS NULL
    ALTER TABLE dbo.udt_companies ADD registration_status VARCHAR(30) NOT NULL
        CONSTRAINT DF_companies_registration_status DEFAULT ('Approved');
GO
IF COL_LENGTH('dbo.udt_companies', 'reviewed_by_userid') IS NULL
    ALTER TABLE dbo.udt_companies ADD reviewed_by_userid VARCHAR(50) NULL;
GO
IF COL_LENGTH('dbo.udt_companies', 'reviewed_at') IS NULL
    ALTER TABLE dbo.udt_companies ADD reviewed_at DATETIME NULL;
GO
IF COL_LENGTH('dbo.udt_companies', 'review_notes') IS NULL
    ALTER TABLE dbo.udt_companies ADD review_notes NVARCHAR(500) NULL;
GO
IF COL_LENGTH('dbo.udt_users', 'is_platform_admin') IS NULL
    ALTER TABLE dbo.udt_users ADD is_platform_admin BIT NOT NULL
        CONSTRAINT DF_users_is_platform_admin DEFAULT (0);
GO

UPDATE dbo.udt_companies
SET registration_status = 'Approved'
WHERE NULLIF(LTRIM(RTRIM(registration_status)), '') IS NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.udt_companies') AND name='IX_companies_registration_status')
    CREATE INDEX IX_companies_registration_status ON dbo.udt_companies(registration_status,is_active,created_at);
GO

CREATE OR ALTER PROCEDURE dbo.udp_verify_otp_and_register
    @Email VARCHAR(255),
    @OTPCode VARCHAR(6),
    @Result INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Result=-5;
    SET @Email=NULLIF(LOWER(LTRIM(RTRIM(@Email))), '');
    SET @OTPCode=NULLIF(LTRIM(RTRIM(@OTPCode)), '');

    DECLARE @RegistrationId INT,@StoredOtp VARCHAR(6),@OtpExpiry DATETIME,
        @UserId VARCHAR(50),@Name VARCHAR(100),@PasswordHash VARBINARY(255),
        @Phone VARCHAR(20),@InviteCode VARCHAR(12),@NewCompanyName NVARCHAR(200),
        @CompanyId INT,@CompanyName NVARCHAR(200),@NewInviteCode VARCHAR(12),@IsFounder BIT=0;

    SELECT TOP(1) @RegistrationId=ID,@StoredOtp=otp,@OtpExpiry=otp_expiry,
        @UserId=user_id,@Name=name,@PasswordHash=password,@Phone=phone,
        @InviteCode=NULLIF(UPPER(LTRIM(RTRIM(invite_code))),''),
        @NewCompanyName=NULLIF(LTRIM(RTRIM(new_company_name)),N'')
    FROM dbo.udt_registration_temp
    WHERE LOWER(LTRIM(RTRIM(email)))=@Email
    ORDER BY ID DESC;

    IF @RegistrationId IS NULL BEGIN SET @Result=-3; RETURN; END;
    IF @OtpExpiry IS NULL OR @OtpExpiry<GETUTCDATE()
    BEGIN DELETE FROM dbo.udt_registration_temp WHERE ID=@RegistrationId; SET @Result=-1; RETURN; END;
    IF @StoredOtp<>@OTPCode BEGIN SET @Result=-2; RETURN; END;

    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS(SELECT 1 FROM dbo.udt_users WITH(UPDLOCK,HOLDLOCK)
                  WHERE (LOWER(LTRIM(RTRIM(mail)))=@Email OR userid=@UserId) AND ISNULL(deleted,0)=0)
        BEGIN ROLLBACK; SET @Result=-4; RETURN; END;

        IF @InviteCode IS NOT NULL
        BEGIN
            SELECT TOP(1) @CompanyId=id,@CompanyName=company_name
            FROM dbo.udt_companies WITH(UPDLOCK,HOLDLOCK)
            WHERE UPPER(LTRIM(RTRIM(invite_code)))=@InviteCode
              AND is_active=1 AND registration_status='Approved';
            IF @CompanyId IS NULL BEGIN ROLLBACK; SET @Result=-6; RETURN; END;
        END
        ELSE IF @NewCompanyName IS NOT NULL
        BEGIN
            IF EXISTS(SELECT 1 FROM dbo.udt_companies WITH(UPDLOCK,HOLDLOCK)
                      WHERE LOWER(LTRIM(RTRIM(company_name)))=LOWER(@NewCompanyName))
            BEGIN ROLLBACK; SET @Result=-7; RETURN; END;
            SET @IsFounder=1; SET @CompanyName=@NewCompanyName;
            DECLARE @Attempt INT=0;
            WHILE @Attempt<50
            BEGIN
                SET @NewInviteCode='CMP'+UPPER(LEFT(REPLACE(CONVERT(VARCHAR(36),NEWID()),'-',''),9));
                IF NOT EXISTS(SELECT 1 FROM dbo.udt_companies WHERE invite_code=@NewInviteCode) BREAK;
                SET @Attempt+=1;
            END;
            IF @Attempt>=50 THROW 52400,'Gagal menghasilkan kode perusahaan unik.',1;
            INSERT dbo.udt_companies(company_name,invite_code,created_by_userid,is_active,registration_status)
            VALUES(@CompanyName,@NewInviteCode,@UserId,0,'PendingVerification');
            SET @CompanyId=CONVERT(INT,SCOPE_IDENTITY());
        END
        ELSE THROW 52401,'Tujuan perusahaan registrasi tidak ditemukan.',1;

        INSERT dbo.udt_users(userid,name,pw,role,mail,phone,active,deleted,wrong_login,createby,created_at,updated_at)
        VALUES(@UserId,@Name,@PasswordHash,
               CASE WHEN @IsFounder=1 THEN 'PendingCompanyFounder' ELSE 'User' END,
               @Email,@Phone,CASE WHEN @IsFounder=1 THEN 0 ELSE 1 END,0,0,
               'SYSTEM_REGISTRATION',GETUTCDATE(),GETUTCDATE());

        INSERT dbo.udt_company_info_user
          (userid,name,mail,employeeID,company_id,company_name,organization,job_position,job_level,employment_status,join_date,created_at,updated_at)
        VALUES(@UserId,@Name,@Email,@UserId,@CompanyId,@CompanyName,
               CASE WHEN @IsFounder=1 THEN 'HRD & GA' ELSE NULL END,
               CASE WHEN @IsFounder=1 THEN 'MENUNGGU VERIFIKASI PERUSAHAAN' ELSE 'KARYAWAN BARU' END,
               CASE WHEN @IsFounder=1 THEN 'PENDING' ELSE NULL END,
               CASE WHEN @IsFounder=1 THEN 'Pending Verification' ELSE 'Active' END,
               CONVERT(DATE,GETDATE()),GETUTCDATE(),GETUTCDATE());

        DELETE FROM dbo.udt_registration_temp WHERE ID=@RegistrationId;
        COMMIT;
        SET @Result=CASE WHEN @IsFounder=1 THEN 2 ELSE 1 END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        SET @Result=-5;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_company_registration_review
    @company_id INT,
    @reviewer_userid VARCHAR(50),
    @approved BIT,
    @review_notes NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS(SELECT 1 FROM dbo.udt_users WHERE userid=@reviewer_userid AND active=1 AND ISNULL(deleted,0)=0 AND is_platform_admin=1)
        THROW 52402,'Hanya Platform Admin yang dapat memverifikasi perusahaan baru.',1;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @FounderUserId VARCHAR(50);
        SELECT @FounderUserId=created_by_userid FROM dbo.udt_companies WITH(UPDLOCK,ROWLOCK)
        WHERE id=@company_id AND registration_status='PendingVerification';
        IF @FounderUserId IS NULL THROW 52403,'Pendaftaran perusahaan tidak ditemukan atau sudah diproses.',1;
        UPDATE dbo.udt_companies
        SET registration_status=CASE WHEN @approved=1 THEN 'Approved' ELSE 'Rejected' END,
            is_active=CASE WHEN @approved=1 THEN 1 ELSE 0 END,
            reviewed_by_userid=@reviewer_userid,reviewed_at=GETUTCDATE(),review_notes=@review_notes
        WHERE id=@company_id AND registration_status='PendingVerification';
        IF @approved=1
        BEGIN
            UPDATE dbo.udt_users SET active=1,role='HRD',updated_at=GETUTCDATE()
            WHERE userid=@FounderUserId AND role='PendingCompanyFounder';
            UPDATE dbo.udt_company_info_user
            SET job_position='HEAD OF HRD & GA',job_level='HEAD',employment_status='Active',updated_at=GETUTCDATE()
            WHERE userid=@FounderUserId AND company_id=@company_id;
        END;
        COMMIT;
        SELECT 1 success,CASE WHEN @approved=1 THEN N'Perusahaan disetujui dan Head HRD telah diaktifkan.' ELSE N'Pendaftaran perusahaan ditolak.' END message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.udp_company_registration_get_pending
    @reviewer_userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS(SELECT 1 FROM dbo.udt_users WHERE userid=@reviewer_userid AND active=1 AND ISNULL(deleted,0)=0 AND is_platform_admin=1)
        THROW 52404,'Hanya Platform Admin yang dapat melihat pendaftaran perusahaan.',1;
    SELECT c.id,c.company_name,c.created_by_userid,u.name founder_name,u.mail founder_email,u.phone founder_phone,
           c.created_at,c.invite_code,c.registration_status
    FROM dbo.udt_companies c
    LEFT JOIN dbo.udt_users u ON u.userid=c.created_by_userid
    WHERE c.registration_status='PendingVerification'
    ORDER BY c.created_at;
END;
GO

SELECT c.id,c.company_name,c.is_active,c.registration_status,c.created_by_userid,c.created_at
FROM dbo.udt_companies c ORDER BY c.id;
GO

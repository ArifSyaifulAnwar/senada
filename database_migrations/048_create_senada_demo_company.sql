/*
  SENADA - Tenant khusus akun demo iOS/Web/Android

  Akun DEMO001 harus tetap memiliki company_id aktif seperti akun biasa.
  Jangan membuat pengecualian di API login karena seluruh endpoint lain juga
  bergantung pada isolasi tenant. Migration ini membuat/mengaktifkan tenant
  SENADA Demo lalu mengaitkan akun demo ke tenant tersebut.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

DECLARE @DemoUserId VARCHAR(50) = 'DEMO001';
DECLARE @DemoCompanyName VARCHAR(200) = 'SENADA Demo';
DECLARE @DemoCompanyId INT;
/* Kolom invite_code pada database lama dibatasi 10 karakter. */
DECLARE @InviteCode VARCHAR(10);
DECLARE @DemoName VARCHAR(200);
DECLARE @DemoEmail VARCHAR(200);

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.udt_users
    WHERE userid = @DemoUserId
      AND active = 1
      AND ISNULL(deleted, 0) = 0
)
BEGIN
    THROW 54800, 'Akun DEMO001 tidak ditemukan atau tidak aktif.', 1;
END;

SELECT TOP (1) @DemoCompanyId = id
FROM dbo.udt_companies WITH (UPDLOCK, HOLDLOCK)
WHERE company_name = @DemoCompanyName;

IF @DemoCompanyId IS NULL
BEGIN
    /* Kode hanya dipakai untuk konsistensi data perusahaan demo. */
    SET @InviteCode = 'DEMO' + UPPER(SUBSTRING(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 1, 6));

    WHILE EXISTS (SELECT 1 FROM dbo.udt_companies WHERE invite_code = @InviteCode)
        SET @InviteCode = 'DEMO' + UPPER(SUBSTRING(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 1, 6));

    INSERT INTO dbo.udt_companies
    (
        company_name,
        invite_code,
        created_by_userid,
        is_active
    )
    VALUES
    (
        @DemoCompanyName,
        @InviteCode,
        @DemoUserId,
        1
    );

    SET @DemoCompanyId = CONVERT(INT, SCOPE_IDENTITY());
END
ELSE
BEGIN
    /* Tenant demo yang pernah dibuat tetap dapat dipakai ulang. */
    UPDATE dbo.udt_companies
    SET is_active = 1
    WHERE id = @DemoCompanyId
      AND ISNULL(is_active, 0) = 0;
END;

SELECT
    @DemoName = NULLIF(LTRIM(RTRIM(name)), ''),
    @DemoEmail = NULLIF(LTRIM(RTRIM(mail)), '')
FROM dbo.udt_users
WHERE userid = @DemoUserId;

IF EXISTS (SELECT 1 FROM dbo.udt_company_info_user WHERE userid = @DemoUserId)
BEGIN
    UPDATE dbo.udt_company_info_user
    SET company_id = @DemoCompanyId,
        company_name = @DemoCompanyName,
        employment_status = 'Active',
        updated_at = GETUTCDATE()
    WHERE userid = @DemoUserId;
END
ELSE
BEGIN
    INSERT INTO dbo.udt_company_info_user
    (
        userid,
        name,
        mail,
        employeeID,
        company_id,
        company_name,
        organization,
        job_position,
        job_level,
        employment_status,
        join_date,
        created_at,
        updated_at
    )
    VALUES
    (
        @DemoUserId,
        COALESCE(@DemoName, @DemoUserId),
        @DemoEmail,
        @DemoUserId,
        @DemoCompanyId,
        @DemoCompanyName,
        'DEMO',
        'DEMO USER',
        NULL,
        'Active',
        CONVERT(DATE, GETDATE()),
        GETUTCDATE(),
        GETUTCDATE()
    );
END;

COMMIT TRANSACTION;
GO

/* Verifikasi: login hanya boleh lanjut bila perusahaan demo aktif dan mapping tepat. */
SELECT
    u.userid,
    u.name,
    u.active AS user_active,
    ISNULL(u.deleted, 0) AS user_deleted,
    ci.company_id,
    ci.company_name,
    co.is_active AS company_active
FROM dbo.udt_users u
INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
INNER JOIN dbo.udt_companies co ON co.id = ci.company_id
WHERE u.userid = 'DEMO001';
GO

/* Informasi pekerjaan pada halaman Info Profil hanya untuk akun peminta. */
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.udp_GetCompanyInfoByUser
    @userid VARCHAR(50),
    @mail   VARCHAR(255) = NULL /* Kompatibilitas klien lama. */
AS
BEGIN
    SET NOCOUNT ON;
    SET @userid = NULLIF(LTRIM(RTRIM(@userid)), '');

    IF @userid IS NULL
        THROW 52700, 'UserId wajib diisi.', 1;

    SELECT TOP (1)
        ci.id, ci.userid, ci.name, ci.mail, ci.employeeID, ci.barcode,
        c.company_name, ci.branch, ci.organization, ci.job_position,
        ci.job_level, ci.employment_status, ci.join_date, ci.end_contract_date,
        ci.working_period_year, ci.working_period_month, ci.working_period_day,
        ci.grade, ci.class, ci.approval_line, ci.manager,
        ci.created_at, ci.updated_at
    FROM dbo.udt_company_info_user ci
    INNER JOIN dbo.udt_users u ON u.userid = ci.userid
    INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
    WHERE ci.userid = @userid
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;
END;
GO

SELECT name, modify_date
FROM sys.procedures
WHERE name = 'udp_GetCompanyInfoByUser';
GO

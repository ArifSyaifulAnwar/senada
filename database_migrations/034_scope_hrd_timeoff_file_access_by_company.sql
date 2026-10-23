/*
  SENADA - Otorisasi lampiran izin untuk HRD per perusahaan

  Endpoint unduh lampiran memakai timeOffId. Procedure ini memastikan ID itu
  masih berada dalam company_id HRD yang sedang login sebelum API membaca path
  file dari server. Jalankan setelah 012_scope_timeoff_by_company.sql.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.udp_timeoff_admin_authorize
    @timeOffId INT,
    @adminId   VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company_id INT;
    DECLARE @has_access BIT = 0;

    SELECT TOP (1)
        @company_id = ci.company_id,
        @has_access = CASE
            WHEN UPPER(ISNULL(u.role, '')) IN ('HRD', 'ADMIN') THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%' THEN 1
            WHEN UPPER(ISNULL(ci.organization, '')) LIKE '%DIREKTUR%' THEN 1
            WHEN UPPER(ISNULL(ci.job_position, '')) LIKE '%DIREKTUR%' THEN 1
            ELSE 0 END
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
    WHERE u.userid = @adminId
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    SELECT CAST(CASE WHEN @has_access = 1 AND EXISTS
    (
        SELECT 1
        FROM dbo.udt_timeoff t
        WHERE t.id = @timeOffId
          AND t.company_id = @company_id
    ) THEN 1 ELSE 0 END AS BIT) AS is_authorized;
END;
GO

SELECT name, modify_date
FROM sys.procedures
WHERE name = 'udp_timeoff_admin_authorize';
GO

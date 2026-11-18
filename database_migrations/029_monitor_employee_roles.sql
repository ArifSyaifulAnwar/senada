/* Tambahkan role pada daftar karyawan terlingkup PT untuk monitor absensi. */
USE [ABSENSI];
GO

CREATE OR ALTER PROCEDURE dbo.udp_admin_get_employees
    @admin_user_id NVARCHAR(50),
    @search_term NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @company_id INT;
    SELECT TOP (1) @company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    WHERE u.userid = @admin_user_id
      AND u.active = 1 AND ISNULL(u.deleted, 0) = 0
      AND (UPPER(ISNULL(u.role, '')) IN ('ADMIN', 'HRD')
           OR UPPER(ISNULL(ci.organization, '')) LIKE '%HRD%');

    IF @company_id IS NULL
        THROW 52106, 'Akses riwayat absensi tidak diizinkan.', 1;

    SELECT u.userid, u.name, u.role,
           ci.employeeID AS employee_id,
           ci.organization AS department,
           ci.job_position AS position,
           u.mail, u.phone, u.active
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci
      ON ci.userid = u.userid AND ci.company_id = @company_id
    WHERE ISNULL(u.deleted, 0) = 0
      AND (@search_term IS NULL OR u.name LIKE '%' + @search_term + '%'
           OR ci.employeeID LIKE '%' + @search_term + '%'
           OR ci.organization LIKE '%' + @search_term + '%')
    ORDER BY u.name;
END;
GO

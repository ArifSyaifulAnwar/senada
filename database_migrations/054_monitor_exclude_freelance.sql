/* Kategori kerja sudah ada di ci.employment_status. Kirim ke monitor dan
   tandai dua akun PT Sedayu Dana Banda yang dikonfirmasi sebagai freelance. */
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
           ci.employment_status,
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

/* Tidak bergantung pada ejaan nama yang dapat berubah. Pastikan tepat dua
   akun yang diverifikasi masih berada pada PT yang dimaksud. */
IF (SELECT COUNT(*)
    FROM dbo.udt_company_info_user ci
    JOIN dbo.udt_companies c ON c.id = ci.company_id
    WHERE ci.userid IN ('26096422', '23020019')
      AND c.company_name = 'PT Sedayu Dana Banda') <> 2
    THROW 55400, 'Akun freelance PT Sedayu Dana Banda tidak cocok; data tidak diubah.', 1;

UPDATE ci
SET employment_status = 'Freelance'
FROM dbo.udt_company_info_user ci
JOIN dbo.udt_companies c ON c.id = ci.company_id
WHERE ci.userid IN ('26096422', '23020019')
  AND c.company_name = 'PT Sedayu Dana Banda';
GO

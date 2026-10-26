/*
  SENADA - Audit akun yang dapat autentikasi tetapi belum siap memakai data PT

  Jangan menebak company_id untuk akun pada hasil audit. HRD/Admin harus
  menetapkan relasi yang benar di udt_company_info_user agar data PT tidak
  tercampur.
*/
USE [ABSENSI];
GO
SET NOCOUNT ON;
GO

SELECT
    u.userid,
    u.name,
    u.mail,
    u.role,
    u.active AS user_active,
    ci.company_id,
    c.company_name,
    c.is_active AS company_active,
    CASE
        WHEN ci.userid IS NULL THEN 'Belum memiliki data company_info_user'
        WHEN ci.company_id IS NULL THEN 'company_id belum diisi'
        WHEN c.id IS NULL THEN 'Perusahaan tidak ditemukan'
        WHEN ISNULL(c.is_active, 0) = 0 THEN 'Perusahaan tidak aktif'
        ELSE 'Siap'
    END AS readiness_status
FROM dbo.udt_users u
LEFT JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
LEFT JOIN dbo.udt_companies c ON c.id = ci.company_id
WHERE u.active = 1
  AND ISNULL(u.deleted, 0) = 0
  AND
  (
      ci.userid IS NULL
      OR ci.company_id IS NULL
      OR c.id IS NULL
      OR ISNULL(c.is_active, 0) = 0
  )
ORDER BY readiness_status, u.name, u.userid;
GO

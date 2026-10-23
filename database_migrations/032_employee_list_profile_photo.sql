/*
  SENADA - Foto profil pada daftar karyawan

  Foto tidak dikirim sebagai base64 dalam response daftar karena dapat membuat
  daftar karyawan lambat/timeout. Client mengambil foto satu per satu hanya
  untuk kartu yang terlihat, dengan hak akses dan company_id yang sama.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.udp_employee_profile_photo_get
    @request_user_id VARCHAR(50),
    @target_id INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company_id INT;
    SELECT TOP (1) @company_id = ci.company_id
    FROM dbo.udt_users requester
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = requester.userid
    INNER JOIN dbo.udt_companies co ON co.id = ci.company_id AND co.is_active = 1
    WHERE requester.userid = @request_user_id
      AND requester.active = 1
      AND ISNULL(requester.deleted, 0) = 0;

    IF @company_id IS NULL
        THROW 53200, 'Akun peminta tidak aktif atau belum terhubung ke perusahaan.', 1;

    SELECT u.FotoProfil
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci
        ON ci.userid = u.userid
       AND ci.company_id = @company_id
    WHERE u.id = @target_id
      AND ISNULL(u.deleted, 0) = 0
      AND u.FotoProfil IS NOT NULL;
END;
GO

SELECT name, modify_date
FROM sys.procedures
WHERE name = 'udp_employee_profile_photo_get';
GO

/*
  SENADA - Edit dan hapus aktivitas harian oleh pemilik

  Pengamanan:
  - user_id diambil dari akun aktif yang memanggil procedure;
  - DELETE selalu dibatasi oleh id aktivitas + userid + company_id;
  - lampiran dihapus dalam transaksi yang sama dengan aktivitasnya.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_DeleteDailyActivity
    @ActivityId INT,
    @UserId VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company_id INT;
    SELECT @company_id = ci.company_id
    FROM dbo.udt_users u
    INNER JOIN dbo.udt_company_info_user ci ON ci.userid = u.userid
    INNER JOIN dbo.udt_companies c ON c.id = ci.company_id AND c.is_active = 1
    WHERE u.userid = @UserId
      AND u.active = 1
      AND ISNULL(u.deleted, 0) = 0;

    IF @company_id IS NULL
        THROW 54000, 'User tidak aktif atau belum terhubung ke perusahaan.', 1;

    BEGIN TRANSACTION;

    DELETE att
    FROM dbo.udt_daily_activity_attachment att
    INNER JOIN dbo.udt_daily_activity a ON a.id = att.activity_id
    WHERE a.id = @ActivityId
      AND a.userid = @UserId
      AND a.company_id = @company_id;

    DELETE FROM dbo.udt_daily_activity
    WHERE id = @ActivityId
      AND userid = @UserId
      AND company_id = @company_id;

    IF @@ROWCOUNT <> 1
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 54001, 'Aktivitas tidak ditemukan atau bukan milik user.', 1;
    END;

    COMMIT TRANSACTION;
END;
GO

SELECT name, modify_date
FROM sys.procedures
WHERE name IN ('usp_UpdateDailyActivity', 'usp_DeleteDailyActivity');
GO

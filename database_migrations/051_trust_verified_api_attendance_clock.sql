/*
  Setelah API yang memverifikasi waktu HTTPS siap dideploy, jalankan migrasi ini.
  Hanya mengubah validasi sumber waktu di prosedur absensi wajah. Jam SQL
  diketahui meleset, sehingga tidak boleh menimpa waktu API yang terverifikasi.
  Memerlukan migrasi 049 lebih dulu. Tidak mengubah jam/konfigurasi server.
*/
USE [ABSENSI];
GO
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @definition NVARCHAR(MAX) =
        OBJECT_DEFINITION(OBJECT_ID(N'dbo.udp_verify_face_attendance_python'));
    DECLARE @start INT, @finish INT, @createPosition INT;

    IF @definition IS NULL
        THROW 55101, 'Prosedur absensi wajah tidak ditemukan.', 1;
    IF @definition NOT LIKE N'%@request_received_utc%AT TIME ZONE ''UTC''%'
        THROW 55102, 'Jalankan migrasi 049 terlebih dahulu.', 1;

    SET @start = CHARINDEX(
        N'DECLARE @server_utc DATETIME2(3) = SYSUTCDATETIME();',
        @definition);
    SET @finish = CHARINDEX(N'DECLARE @now DATETIME = CONVERT(',
        @definition, @start);

    IF @start = 0
    BEGIN
        /* Sudah terpasang: blok waktu DB lama tidak ada lagi. */
        COMMIT TRANSACTION;
        SELECT N'SUDAH TERPASANG' AS status;
        RETURN;
    END;
    IF @finish <= @start
        THROW 55103, 'Blok waktu prosedur tidak dikenali; tidak ada perubahan.', 1;

    SET @definition = STUFF(
        @definition, @start, @finish - @start,
        N'IF @request_received_utc IS NULL
            THROW 55104, ''Waktu request API wajib diverifikasi.'', 1;

        ');

    IF UPPER(LTRIM(@definition)) LIKE N'CREATE%PROCEDURE%'
       AND UPPER(LTRIM(@definition)) NOT LIKE N'CREATE OR ALTER%'
    BEGIN
        SET @createPosition = CHARINDEX(N'CREATE', UPPER(@definition));
        SET @definition = STUFF(@definition, @createPosition, LEN(N'CREATE'), N'ALTER');
    END;

    EXEC sys.sp_executesql @definition;

    IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.udp_verify_face_attendance_python'))
        NOT LIKE N'%THROW 55104%'
        THROW 55105, 'Validasi migrasi waktu absensi gagal.', 1;

    COMMIT TRANSACTION;
    SELECT N'BERHASIL - waktu absensi dari API terverifikasi' AS status;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

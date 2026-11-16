

USE ABSENSI;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @definition NVARCHAR(MAX) =
        OBJECT_DEFINITION(OBJECT_ID(N'dbo.udp_verify_face_attendance_python'));
    DECLARE @timeStart INT;
    DECLARE @timeEnd INT;
    DECLARE @createPosition INT;
    DECLARE @newTimeBlock NVARCHAR(MAX);

    IF @definition IS NULL
        THROW 54901, 'SP dbo.udp_verify_face_attendance_python tidak ditemukan.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.parameters
        WHERE object_id = OBJECT_ID(N'dbo.udp_verify_face_attendance_python')
          AND name = N'@request_received_utc'
    )
        THROW 54902, 'Parameter @request_received_utc belum ada. Deploy API dan migration waktu request sebelumnya terlebih dahulu.', 1;

    /* SP sudah memakai waktu request API: tidak ada perubahan yang diperlukan. */
    IF @definition LIKE N'%@request_received_utc%AT TIME ZONE ''UTC''%'
    BEGIN
        COMMIT TRANSACTION;
        SELECT N'SUDAH REAL-TIME - tidak ada perubahan' AS status;
        RETURN;
    END;

    /*
      Patching hanya dilakukan pada blok waktu yang diketahui. Jangan mengganti
      GETDATE() secara global karena dapat memengaruhi audit/bisnis lain di SP.
    */
    SET @timeStart = CHARINDEX(N'DECLARE @now DATETIME = CONVERT(', @definition);
    SET @timeEnd = CHARINDEX(N'DECLARE @today', @definition, @timeStart);

    IF @timeStart = 0 OR @timeEnd = 0
        THROW 54903, 'Blok sumber waktu @now pada SP tidak dikenali; tidak ada perubahan dibuat.', 1;

    SET @newTimeBlock =
        N'DECLARE @server_utc DATETIME2(3) = SYSUTCDATETIME();

        /* Tolak timestamp tidak wajar; waktu tetap sepenuhnya dikendalikan server. */
        IF @request_received_utc IS NULL
           OR @request_received_utc < DATEADD(MINUTE, -15, @server_utc)
           OR @request_received_utc > DATEADD(MINUTE, 1, @server_utc)
        BEGIN
            SET @request_received_utc = @server_utc;
        END;

        /* Waktu tersimpan = saat request masuk API, dalam zona WIB. */
        DECLARE @now DATETIME = CONVERT(
            DATETIME,
            @request_received_utc
                AT TIME ZONE ''UTC''
                AT TIME ZONE ''SE Asia Standard Time''
        );

        ';

    SET @definition = STUFF(
        @definition,
        @timeStart,
        @timeEnd - @timeStart,
        @newTimeBlock
    );

    /* OBJECT_DEFINITION dapat berisi CREATE PROCEDURE atau CREATE OR ALTER. */
    IF UPPER(LTRIM(@definition)) LIKE N'CREATE%PROCEDURE%'
       AND UPPER(LTRIM(@definition)) NOT LIKE N'CREATE OR ALTER%'
    BEGIN
        SET @createPosition = CHARINDEX(N'CREATE', UPPER(@definition));
        SET @definition = STUFF(@definition, @createPosition, LEN(N'CREATE'), N'ALTER');
    END;

    EXEC sys.sp_executesql @definition;

    IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.udp_verify_face_attendance_python'))
       NOT LIKE N'%@request_received_utc%AT TIME ZONE ''UTC''%'
        THROW 54904, 'Validasi perubahan sumber waktu SP gagal.', 1;

    COMMIT TRANSACTION;

    SELECT N'BERHASIL - waktu absensi memakai waktu request masuk API' AS status;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

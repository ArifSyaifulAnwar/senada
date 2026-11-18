/*
  Diagnostik read-only untuk selisih waktu absensi.
  Jalankan di SSMS pada database ABSENSI; tidak mengubah data atau konfigurasi.
  Bandingkan db_wib di bawah dengan jam WIB tepercaya pada saat query dijalankan.
*/
USE [ABSENSI];
GO
SET NOCOUNT ON;

SELECT
    SYSUTCDATETIME() AS db_utc,
    SYSDATETIMEOFFSET() AS db_local_with_offset,
    CONVERT(DATETIME2(3),
        SYSUTCDATETIME() AT TIME ZONE 'UTC'
            AT TIME ZONE 'SE Asia Standard Time') AS db_wib,
    CASE WHEN EXISTS (
        SELECT 1 FROM sys.parameters
        WHERE object_id = OBJECT_ID(N'dbo.udp_verify_face_attendance_python')
          AND name = N'@request_received_utc'
    ) THEN 1 ELSE 0 END AS accepts_api_request_time,
    CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.udp_verify_face_attendance_python'))
        LIKE N'%@request_received_utc%AT TIME ZONE ''UTC''%'
        THEN 1 ELSE 0 END AS uses_api_request_time;
GO

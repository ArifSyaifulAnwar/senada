{{flutter_js}}
{{flutter_build_config}}

// The wall-mounted monitor must remain usable on browsers whose WebGL shader
// compiler cannot render CanvasKit. Leave the rest of the app on its default.
const monitorPath = window.location.pathname.replace(/\/+$/, '').endsWith('/monitor');
const monitorHash = window.location.hash.replace(/\/+$/, '') === '#/monitor';
const useMonitorCpu = monitorPath || monitorHash;

_flutter.loader.load({
  config: useMonitorCpu
    ? { renderer: 'canvaskit', canvasKitForceCpuOnly: true }
    : {},
});

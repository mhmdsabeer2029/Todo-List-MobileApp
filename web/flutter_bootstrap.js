{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: document.getElementById('flutter-target'),
    });
    await appRunner.runApp();
    // Fade out the splash screen once the app is running
    var splash = document.getElementById('splash');
    if (splash) {
      splash.classList.add('hidden');
      setTimeout(function() { splash.remove(); }, 350);
    }
  },
});

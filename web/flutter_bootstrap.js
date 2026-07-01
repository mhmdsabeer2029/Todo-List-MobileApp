{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine({
        hostElement: document.getElementById('flutter-target'),
      });
      await appRunner.runApp();

      // Flutter is running — fade out and remove the splash screen
      var splash = document.getElementById('splash');
      if (splash) {
        splash.classList.add('hidden');
        // Remove from DOM after the CSS transition completes (400ms)
        setTimeout(function() {
          if (splash.parentNode) splash.parentNode.removeChild(splash);
        }, 450);
      }
    } catch (err) {
      // Show error state in splash instead of infinite spinner
      console.error('Flutter failed to initialize:', err);
      var bar   = document.getElementById('splash-bar');
      var error = document.getElementById('splash-error');
      if (bar)   bar.style.display   = 'none';
      if (error) error.style.display = 'block';
    }
  },
});

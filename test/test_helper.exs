
# capture_log: true + starting :logger == total red-error-from-crashing suppression
:ok = Application.ensure_started(:logger)
ExUnit.start(capture_log: true)


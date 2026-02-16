part of mapbox_maps_flutter;

class MockLocationController {
  static const _channel = MethodChannel('mock_location_channel');

  static Future<void> setLocation({
    required double latitude,
    required double longitude,
    double? bearing,
    required int durationMs,
    CameraOptions? cameraOptions,
  }) async {
    await _channel.invokeMethod('setMockLocation', {
      'latitude': latitude,
      'longitude': longitude,
      'bearing': bearing,
      'duration' : durationMs,
      'cameraOptions' : cameraOptions?.toMap(),
    });
  }
}
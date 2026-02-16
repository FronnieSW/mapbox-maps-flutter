package com.mapbox.maps.mapbox_maps.pigeon

import android.animation.ValueAnimator
import com.mapbox.geojson.Point
import com.mapbox.maps.MapView
import com.mapbox.maps.plugin.locationcomponent.location
import com.mapbox.maps.plugin.locationcomponent.LocationConsumer
import com.mapbox.maps.plugin.locationcomponent.LocationProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.view.animation.LinearInterpolator
import com.mapbox.maps.CameraOptions
import com.mapbox.maps.dsl.cameraOptions
import com.mapbox.maps.plugin.animation.CameraAnimatorType
import com.mapbox.maps.plugin.animation.MapAnimationOptions
import com.mapbox.maps.plugin.animation.easeTo
import com.mapbox.maps.plugin.animation.flyTo
class MockLocation(
  val latitude: Double,
  val longitude: Double,
  val bearing: Double? = null,
  val durationMs: Long
)
interface MockLocationApi {
  fun setMockLocation(location: MockLocation, cameraOptions: CameraOptions?)
}
class CustomLocationProvider : LocationProvider {
  private var consumer: LocationConsumer? = null

  override fun registerLocationConsumer(locationConsumer: LocationConsumer) {
    consumer = locationConsumer
  }

  override fun unRegisterLocationConsumer(locationConsumer: LocationConsumer) {
    consumer = null
  }

  fun updateLocation(lat: Double, lon: Double, bearing: Double?, durationMs: Long) {
    val point = Point.fromLngLat(lon, lat)
    if (bearing != null) {
      consumer?.onBearingUpdated(bearing)
    }
    consumer?.onLocationUpdated(point) {
      duration = durationMs
      interpolator = LinearInterpolator()
    }
  }
}
class MockLocationApiImpl(
  private val mapView: MapView,
  messenger: BinaryMessenger
) : MockLocationApi, MethodCallHandler {

  private val customProvider = CustomLocationProvider()
  private val channel = MethodChannel(messenger, "mock_location_channel")

  init {
    mapView.location.setLocationProvider(customProvider)
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "setMockLocation" -> {
        val lat = call.argument<Double>("latitude") ?: return result.error(
          "MISSING",
          "latitude missing",
          null
        )
        val lon = call.argument<Double>("longitude") ?: return result.error(
          "MISSING",
          "longitude missing",
          null
        )
        val bearing = call.argument<Double>("bearing")
        val durationMs = call.argument<Number>("duration")?.toLong() ?: 1000L

        val cameraOptionsMap = call.argument<Map<String, Any?>>("cameraOptions")
        val options = cameraOptionsMap?.let { map ->
          CameraOptions.Builder().apply {
            (map["center"] as? Map<*, *>)?.let { centerMap ->
              val lat = (centerMap["latitude"] as? Number)?.toDouble()
              val lon = (centerMap["longitude"] as? Number)?.toDouble()
              if (lat != null && lon != null) {
                center(Point.fromLngLat(lon, lat))
              }
            }
            (map["zoom"] as? Number)?.toDouble()?.let { zoom(it) }
            (map["bearing"] as? Number)?.toDouble()?.let { bearing(it) }
            (map["pitch"] as? Number)?.toDouble()?.let { pitch(it) }
          }.build()
        }
        setMockLocation(MockLocation(lat, lon, bearing, durationMs), options)
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  override fun setMockLocation(location: MockLocation, cameraOptions: CameraOptions?) {
    customProvider.updateLocation(
      location.latitude,
      location.longitude,
      location.bearing,
      location.durationMs,
    )
    if (cameraOptions != null) {
      mapView.mapboxMap.flyTo(
        cameraOptions,
        MapAnimationOptions.mapAnimationOptions {
          duration(location.durationMs)
          startDelay(0)
          interpolator(LinearInterpolator())
        },
      )
    }
  }
}
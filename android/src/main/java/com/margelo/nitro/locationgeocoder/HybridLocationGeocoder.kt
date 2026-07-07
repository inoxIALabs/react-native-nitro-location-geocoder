package com.margelo.nitro.locationgeocoder

import android.location.Address
import android.location.Geocoder
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresApi
import com.facebook.proguard.annotations.DoNotStrip
import com.margelo.nitro.NitroModules
import com.margelo.nitro.core.Promise
import java.io.IOException
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

@DoNotStrip
class HybridLocationGeocoder : HybridLocationGeocoderSpec() {

    private val context
        get() = NitroModules.applicationContext
            ?: throw RuntimeException("Application context not available")

    private fun getLocale(locale: String): Locale {
        val normalized = locale.trim()
        if (normalized.isEmpty()) return Locale.getDefault()
        return Locale.forLanguageTag(normalized)
    }

    private fun createGeocoder(locale: String): Geocoder {
        return Geocoder(context, getLocale(locale))
    }

    private fun isValidCoordinate(latitude: Double, longitude: Double): Boolean {
        return latitude.isFinite() &&
            longitude.isFinite() &&
            latitude >= -90.0 &&
            latitude <= 90.0 &&
            longitude >= -180.0 &&
            longitude <= 180.0
    }

    private fun geocoderFailed(message: String?): Exception {
        val normalized = message?.trim()?.takeIf { it.isNotEmpty() }
        return Exception(if (normalized == null) "GEOCODER_FAILED" else "GEOCODER_FAILED: $normalized")
    }

    override fun reverseGeocode(
        latitude: Double,
        longitude: Double,
        locale: String
    ): Promise<LocationGeocoderResult> {
        if (!isValidCoordinate(latitude, longitude)) {
            return Promise.rejected(Exception("INVALID_COORDINATES"))
        }

        if (!Geocoder.isPresent()) {
            return Promise.rejected(Exception("UNAVAILABLE"))
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return reverseGeocodeApi33(latitude, longitude, locale)
        }

        return Promise.async {
            val address = try {
                reverseGeocodeLegacy(latitude, longitude, locale)
            } catch (error: IllegalArgumentException) {
                throw Exception("INVALID_COORDINATES")
            } catch (error: IOException) {
                throw geocoderFailed(error.message)
            } ?: throw Exception("NO_RESULTS")

            mapAddress(address)
        }
    }

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun reverseGeocodeApi33(
        latitude: Double,
        longitude: Double,
        locale: String
    ): Promise<LocationGeocoderResult> {
        val promise = Promise<LocationGeocoderResult>()
        val geocoder = createGeocoder(locale)
        val handler = Handler(Looper.getMainLooper())
        val didComplete = AtomicBoolean(false)

        lateinit var timeoutRunnable: Runnable

        fun completeOnce(block: () -> Unit) {
            val finish = finish@{
                if (!didComplete.compareAndSet(false, true)) {
                    return@finish
                }

                handler.removeCallbacks(timeoutRunnable)
                block()
            }

            if (Looper.myLooper() == Looper.getMainLooper()) {
                finish()
            } else {
                handler.post {
                    finish()
                }
            }
        }

        fun rejectOnce(error: Exception) {
            completeOnce {
                promise.reject(error)
            }
        }

        fun resolveOnce(address: Address?) {
            completeOnce {
                if (address == null) {
                    promise.reject(Exception("NO_RESULTS"))
                    return@completeOnce
                }

                promise.resolve(mapAddress(address))
            }
        }

        timeoutRunnable = Runnable {
            rejectOnce(Exception("GEOCODER_TIMEOUT"))
        }
        handler.postDelayed(timeoutRunnable, TIMEOUT_MS)

        try {
            geocoder.getFromLocation(latitude, longitude, 1, object : Geocoder.GeocodeListener {
                override fun onGeocode(addresses: MutableList<Address>) {
                    resolveOnce(addresses.firstOrNull())
                }

                override fun onError(errorMessage: String?) {
                    rejectOnce(geocoderFailed(errorMessage))
                }
            })
        } catch (error: IllegalArgumentException) {
            rejectOnce(Exception("INVALID_COORDINATES"))
        } catch (error: IOException) {
            rejectOnce(geocoderFailed(error.message))
        }

        return promise
    }

    @Suppress("DEPRECATION")
    private fun reverseGeocodeLegacy(latitude: Double, longitude: Double, locale: String): Address? {
        return createGeocoder(locale).getFromLocation(latitude, longitude, 1)?.firstOrNull()
    }

    private fun mapAddress(address: Address): LocationGeocoderResult {
        return LocationGeocoderResult(
            countryCode = address.countryCode ?: "",
            country = address.countryName ?: "",
            locality = address.locality ?: "",
            administrativeArea = address.adminArea ?: "",
            subAdministrativeArea = address.subAdminArea ?: "",
            subLocality = address.subLocality ?: ""
        )
    }

    private companion object {
        private const val TIMEOUT_MS = 10_000L
    }
}

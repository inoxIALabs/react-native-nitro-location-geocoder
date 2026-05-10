package com.margelo.nitro.locationgeocoder

import android.location.Address
import android.location.Geocoder
import android.os.Build
import androidx.annotation.RequiresApi
import com.facebook.proguard.annotations.DoNotStrip
import com.margelo.nitro.NitroModules
import com.margelo.nitro.core.Promise
import java.io.IOException
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

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
        return Promise.async {
            if (!isValidCoordinate(latitude, longitude)) {
                throw Exception("INVALID_COORDINATES")
            }

            if (!Geocoder.isPresent()) {
                throw Exception("UNAVAILABLE")
            }

            val address = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    reverseGeocodeApi33(latitude, longitude, locale)
                } else {
                    reverseGeocodeLegacy(latitude, longitude, locale)
                }
            } catch (error: IllegalArgumentException) {
                throw Exception("INVALID_COORDINATES")
            } catch (error: IOException) {
                throw geocoderFailed(error.message)
            } catch (error: InterruptedException) {
                Thread.currentThread().interrupt()
                throw geocoderFailed(error.message)
            } ?: throw Exception("NO_RESULTS")

            mapAddress(address)
        }
    }

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun reverseGeocodeApi33(latitude: Double, longitude: Double, locale: String): Address? {
        val geocoder = createGeocoder(locale)
        val resultRef = AtomicReference<Address?>()
        val errorRef = AtomicReference<Exception?>()
        val latch = CountDownLatch(1)

        geocoder.getFromLocation(latitude, longitude, 1, object : Geocoder.GeocodeListener {
            override fun onGeocode(addresses: MutableList<Address>) {
                resultRef.set(addresses.firstOrNull())
                latch.countDown()
            }

            override fun onError(errorMessage: String?) {
                errorRef.set(geocoderFailed(errorMessage))
                latch.countDown()
            }
        })

        val completed = latch.await(10, TimeUnit.SECONDS)
        if (!completed) {
            throw Exception("GEOCODER_TIMEOUT")
        }

        errorRef.get()?.let { throw it }
        return resultRef.get()
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
}

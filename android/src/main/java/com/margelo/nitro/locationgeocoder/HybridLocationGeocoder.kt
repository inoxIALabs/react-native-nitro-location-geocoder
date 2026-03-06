package com.margelo.nitro.locationgeocoder

import android.location.Address
import android.location.Geocoder
import android.os.Build
import androidx.annotation.RequiresApi
import com.facebook.proguard.annotations.DoNotStrip
import com.margelo.nitro.NitroModules
import com.margelo.nitro.core.Promise
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

    override fun reverseGeocode(
        latitude: Double,
        longitude: Double,
        locale: String
    ): Promise<LocationGeocoderResult> {
        return Promise.async {
            if (!Geocoder.isPresent()) {
                throw Exception("UNAVAILABLE")
            }

            val address = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                reverseGeocodeApi33(latitude, longitude, locale)
            } else {
                reverseGeocodeLegacy(latitude, longitude, locale)
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
                errorRef.set(Exception(errorMessage ?: "GEOCODER_ERROR"))
                latch.countDown()
            }
        })

        val completed = latch.await(15, TimeUnit.SECONDS)
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

# @inoxialabs/react-native-nitro-location-geocoder

`@inoxialabs/react-native-nitro-location-geocoder` is a minimal React Native Nitro module for reverse geocoding latitude and longitude coordinates into a normalized location result.

## Features

- Reverse geocoding on iOS and Android.
- Locale-aware lookups using language tags. For example: `en`, `es`, or `es-PE`.
- Small, typed API with a normalized result shape.
- No backend dependency and no device location permission requirement.
- Stable generic errors for unavailable geocoders, empty results, invalid coordinates, timeouts, and native geocoder failures.

## Supported platforms

- iOS
- Android

This package does not expose a web implementation.

## Installation

Install the package and its Nitro peer dependency:

```bash
npm install @inoxialabs/react-native-nitro-location-geocoder react-native-nitro-modules
```

Peer dependencies:

- `react`
- `react-native`
- `react-native-nitro-modules` `>=0.35.0`

On iOS, install pods after adding the package:

```bash
cd ios && pod install
```

### Swift requirements

Version 2 requires the Swift 6 language mode and a Swift 6 toolchain on iOS (Xcode 16 or newer; your React Native version may require a newer Xcode). The podspec sets `swift_version = '6.0'`, and Swift 5 language mode is no longer supported for this pod. Swift 6 enables complete concurrency checking by default, so actor isolation and `Sendable` violations are compiler errors. See the [Swift 6 migration guide](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/enabledataracesafety/).

The pod sets its own language mode independently of the app target. Other targets can adopt Swift 6 separately. This implementation uses explicit actor isolation and does not require `SWIFT_APPROACHABLE_CONCURRENCY` or reduced concurrency checking.

The iOS deployment target follows React Native's `min_ios_version_supported`.

## Migrating from 1.x to 2.x

Version 2.0.0 is a major release because it raises the iOS compiler requirement to Swift 6. The iOS request lifecycle now uses explicit actor isolation to coordinate responses, timeouts, and resource cleanup.

1. Use an Xcode version that meets both the Swift requirements above and the requirements of your React Native version.
2. Update the package to version 2 and reinstall pods using the installation commands above.
3. Remove any `Podfile` or build-setting override that forces `NitroLocationGeocoder` to Swift 5. Its podspec selects Swift 6. Keep overrides for other pods scoped to those pods; the app and other dependencies can retain their own Swift language modes.
4. Rebuild the native app. Reloading JavaScript alone does not apply native dependency changes.

No JavaScript or TypeScript API changes are required: exports, method parameters, result fields, error messages, and timeout behavior remain the same. Android behavior and the iOS deployment-target policy are unchanged.

## Usage

```ts
import { reverseGeocode } from '@inoxialabs/react-native-nitro-location-geocoder';

const result = await reverseGeocode(-12.0464, -77.0428, 'es-PE');

console.log(result.countryCode);
console.log(result.country);
console.log(result.locality);
console.log(result.administrativeArea);
```

To use the system default locale, pass an empty string:

```ts
const result = await reverseGeocode(4.711, -74.0721, '');
```

## API

### `reverseGeocode(latitude, longitude, locale)`

Returns `Promise<LocationGeocoderResult>`.

Parameters:

- `latitude`: required `number`
- `longitude`: required `number`
- `locale`: required `string`

`locale` accepts a language tag such as `en`, `es`, or `es-PE`. Passing `''` uses the platform default locale, but the argument itself is still required.
Latitude must be finite and between `-90` and `90`. Longitude must be finite and between `-180` and `180`.

### `LocationGeocoderResult`

```ts
type LocationGeocoderResult = {
  countryCode: string;
  country: string;
  locality: string;
  administrativeArea: string;
  subAdministrativeArea: string;
  subLocality: string;
};
```

All fields are always present. When the platform geocoder cannot provide a field, the module returns an empty string for that property.

## Platform behavior

- iOS uses `CLGeocoder`.
- Android uses `android.location.Geocoder`; Android 13+ uses the callback-based API, while older Android versions use the legacy API off the main thread.
- Calls are independent. Starting one reverse-geocode request does not cancel another request.
- iOS and Android 13+ requests time out after 10 seconds with `GEOCODER_TIMEOUT`.
- On iOS, each request completes once and releases its native resources. A timeout cancels the platform request; late or duplicate callbacks are ignored.
- Android 12 and earlier depend on the legacy platform geocoder returning or failing.
- Timeout behavior is owned by the native module where supported. Callers should avoid adding a second JavaScript timeout unless they intentionally need a stricter app-level deadline.
- The module rejects with `INVALID_COORDINATES` when latitude or longitude is outside the valid coordinate range.
- The module rejects with `NO_RESULTS` when no address is found.
- Android rejects with `UNAVAILABLE` when the platform geocoder is not available.
- iOS wraps native geocoder failures as `GEOCODER_FAILED: <platform message>`.
- Android wraps native geocoder failures as `GEOCODER_FAILED` or `GEOCODER_FAILED: <platform message>`.

## Notes

- The module reverse geocodes coordinates that you already have. It does not request GPS updates or device location permissions.
- The package exports `reverseGeocode`, `Geocoder`, and the default `Geocoder` object.

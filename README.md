# @inoxialabs/react-native-nitro-location-geocoder

React Native Nitro module for reverse geocoding latitude and longitude coordinates into a normalized location result.

## Features

- Reverse geocoding on iOS and Android.
- Locale-aware lookups using language tags such as `en`, `es`, or `es-PE`.
- Small, typed API with a normalized result shape.
- No backend dependency and no device location permission requirement.

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
- `react-native-nitro-modules` `^0.35.0`

On iOS, install pods after adding the package:

```bash
cd ios && pod install
```

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
- Android uses `android.location.Geocoder`.
- The module rejects with `NO_RESULTS` when no address is found.
- Android rejects with `UNAVAILABLE` when the platform geocoder is not available.
- Android API 33+ requests time out after 15 seconds with `GEOCODER_TIMEOUT`.
- iOS wraps native geocoder failures as `GEOCODER_FAILED: <platform message>`.
- Android may surface platform geocoder error messages directly.

## Notes

- The module reverse geocodes coordinates that you already have. It does not request GPS updates or device location permissions.
- The package exports `reverseGeocode`, `Geocoder`, and the default `Geocoder` object.

## Development

Regenerate Nitro bindings after changing `src/specs/LocationGeocoder.nitro.ts` or `nitro.json`:

```bash
npm install
npm run specs
npm test
```

Validate the published package contents:

```bash
npm pack --dry-run
```

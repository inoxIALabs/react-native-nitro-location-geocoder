# @inoxialabs/react-native-nitro-location-geocoder

`@inoxialabs/react-native-nitro-location-geocoder` is a minimal React Native Nitro module for reverse geocoding latitude and longitude coordinates into normalized country and locality data.

## Features

- Native reverse geocoding on both platforms.
- Locale-aware lookups through a language tag such as `en`, `es`, or `es-PE`.
- Normalized result shape for country, locality, and administrative subdivisions.
- Promise-based API exposed through `react-native-nitro-modules`.
- No product-specific logic or backend dependencies.

## Installation

With npm v7 or newer, this is usually enough:

```bash
npm install @inoxialabs/react-native-nitro-location-geocoder
```

This package declares the following peer dependencies:

- `react`
- `react-native`
- `react-native-nitro-modules`

If your package manager does not install peer dependencies automatically, install `react-native-nitro-modules` manually:

```bash
npm install @inoxialabs/react-native-nitro-location-geocoder react-native-nitro-modules
```

iOS:

```bash
cd ios && pod install
```

## Usage

```ts
import { reverseGeocode } from '@inoxialabs/react-native-nitro-location-geocoder';

const result = await reverseGeocode(4.711, -74.0721, 'es-CO');

console.log(result.countryCode);
console.log(result.country);
console.log(result.locality);
```

## API

### `reverseGeocode(latitude, longitude, locale)`

Returns `Promise<LocationGeocoderResult>`.

`LocationGeocoderResult` fields:

- `countryCode`
- `country`
- `locality`
- `administrativeArea`
- `subAdministrativeArea`
- `subLocality`

## Platform behavior

- iOS uses `CLGeocoder`.
- Android uses `android.location.Geocoder`.
- Empty fields are returned as empty strings when the platform geocoder does not provide a value.
- The module rejects when the platform geocoder fails or returns no results.
- Common error values include `NO_RESULTS`, `UNAVAILABLE`, `GEOCODER_TIMEOUT`, or platform geocoder error messages.

## Development

Regenerate Nitro bindings after changing the `.nitro.ts` spec or `nitro.json`:

```bash
npm install
npm run specs
npm test
```

Validate the package contents before publishing:

```bash
npm pack --dry-run
```

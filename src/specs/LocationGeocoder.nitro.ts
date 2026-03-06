import type { HybridObject } from 'react-native-nitro-modules';

export interface LocationGeocoderResult {
  countryCode: string;
  country: string;
  locality: string;
  administrativeArea: string;
  subAdministrativeArea: string;
  subLocality: string;
}

export interface LocationGeocoder extends HybridObject<{ ios: 'swift'; android: 'kotlin' }> {
  reverseGeocode(latitude: number, longitude: number, locale: string): Promise<LocationGeocoderResult>;
}

import { NitroModules } from 'react-native-nitro-modules';
import type { LocationGeocoder, LocationGeocoderResult } from './specs/LocationGeocoder.nitro';

const KNOWN_ERROR_MESSAGES = [
  'GEOCODER_FAILED',
  'GEOCODER_TIMEOUT',
  'INVALID_COORDINATES',
  'NO_RESULTS',
  'UNAVAILABLE',
] as const;

const createGeocoder = (): LocationGeocoder => {
  return NitroModules.createHybridObject<LocationGeocoder>('LocationGeocoder');
};

const Geocoder = createGeocoder();

const isValidLatitude = (latitude: number): boolean =>
  Number.isFinite(latitude) && latitude >= -90 && latitude <= 90;

const isValidLongitude = (longitude: number): boolean =>
  Number.isFinite(longitude) && longitude >= -180 && longitude <= 180;

const normalizeGeocoderError = (error: unknown): Error => {
  const message = error instanceof Error
    ? error.message
    : String((error as { message?: unknown } | null)?.message ?? error ?? '');

  if (KNOWN_ERROR_MESSAGES.some((known) => message.startsWith(known))) {
    return error instanceof Error ? error : new Error(message);
  }

  return new Error(`GEOCODER_FAILED${message ? `: ${message}` : ''}`);
};

export const reverseGeocode = (
  latitude: number,
  longitude: number,
  locale: string,
): Promise<LocationGeocoderResult> => {
  if (!isValidLatitude(latitude) || !isValidLongitude(longitude)) {
    return Promise.reject(new Error('INVALID_COORDINATES'));
  }

  return Geocoder.reverseGeocode(latitude, longitude, locale).catch((error: unknown) => {
    throw normalizeGeocoderError(error);
  });
};

export { Geocoder };
export type { LocationGeocoder, LocationGeocoderResult };

export default Geocoder;

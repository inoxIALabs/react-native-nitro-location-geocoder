import { NitroModules } from 'react-native-nitro-modules';
import type { LocationGeocoder, LocationGeocoderResult } from './specs/LocationGeocoder.nitro';

const createGeocoder = (): LocationGeocoder => {
  return NitroModules.createHybridObject<LocationGeocoder>('LocationGeocoder');
};

const Geocoder = createGeocoder();

export const reverseGeocode = (
  latitude: number,
  longitude: number,
  locale: string,
): Promise<LocationGeocoderResult> => {
  return Geocoder.reverseGeocode(latitude, longitude, locale);
};

export { Geocoder };
export type { LocationGeocoder, LocationGeocoderResult };

export default Geocoder;

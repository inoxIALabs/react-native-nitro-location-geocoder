import { describe, expect, it } from 'vitest';
import Geocoder, { reverseGeocode } from '../src/index';
import {
  createHybridObjectMock,
  reverseGeocodeMock,
} from './mocks/react-native-nitro-modules';

describe('public API', () => {
  it('creates the LocationGeocoder hybrid object on module load', () => {
    expect(createHybridObjectMock).toHaveBeenCalledTimes(1);
    expect(createHybridObjectMock).toHaveBeenCalledWith('LocationGeocoder');
    expect(Geocoder).toBeDefined();
  });

  it('delegates reverseGeocode to the native implementation', async () => {
    const result = {
      countryCode: 'CO',
      country: 'Colombia',
      locality: 'Bogota',
      administrativeArea: 'Bogota D.C.',
      subAdministrativeArea: 'Bogota',
      subLocality: 'Chapinero',
    };

    reverseGeocodeMock.mockResolvedValue(result);

    await expect(reverseGeocode(4.711, -74.0721, 'es-CO')).resolves.toEqual(result);
    expect(reverseGeocodeMock).toHaveBeenCalledWith(4.711, -74.0721, 'es-CO');
  });
});

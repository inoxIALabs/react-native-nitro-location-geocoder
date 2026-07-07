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

  it('rejects invalid coordinates before calling native code', async () => {
    reverseGeocodeMock.mockClear();

    await expect(reverseGeocode(Number.NaN, -74.0721, 'es-CO')).rejects.toThrow(
      'INVALID_COORDINATES',
    );
    await expect(reverseGeocode(4.711, -181, 'es-CO')).rejects.toThrow(
      'INVALID_COORDINATES',
    );
    expect(reverseGeocodeMock).not.toHaveBeenCalled();
  });

  it.each([
    'GEOCODER_FAILED',
    'GEOCODER_TIMEOUT',
    'INVALID_COORDINATES',
    'NO_RESULTS',
    'UNAVAILABLE',
  ])('preserves known native geocoder error %s', async (message) => {
    reverseGeocodeMock.mockRejectedValueOnce(new Error(message));

    await expect(reverseGeocode(4.711, -74.0721, 'es-CO')).rejects.toThrow(message);
  });

  it('normalizes unknown native errors as geocoder failures', async () => {
    reverseGeocodeMock.mockRejectedValueOnce(new Error('network unavailable'));

    await expect(reverseGeocode(4.711, -74.0721, 'es-CO')).rejects.toThrow(
      'GEOCODER_FAILED: network unavailable',
    );
  });
});

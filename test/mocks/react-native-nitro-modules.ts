import { vi } from 'vitest';

export const reverseGeocodeMock = vi.fn();
export const createHybridObjectMock = vi.fn(() => ({
  reverseGeocode: reverseGeocodeMock,
}));

export const NitroModules = {
  createHybridObject: createHybridObjectMock,
};

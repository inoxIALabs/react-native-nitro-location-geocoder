import path from 'node:path';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: {
    alias: {
      'react-native-nitro-modules': path.resolve(__dirname, 'test/mocks/react-native-nitro-modules.ts'),
    },
  },
  test: {
    environment: 'node',
  },
});

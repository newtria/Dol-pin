import type {NextConfig} from 'next';
const config: NextConfig = {
  distDir: process.env.DOLPIN_NEXT_DIST_DIR ?? '.next',
  transpilePackages: ['@dolpin/contracts', '@dolpin/api-client'],
};
export default config;

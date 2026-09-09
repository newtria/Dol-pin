import type {NextConfig} from 'next';
const config: NextConfig = {
  transpilePackages: ['@dolpin/contracts', '@dolpin/api-client'],
};
export default config;

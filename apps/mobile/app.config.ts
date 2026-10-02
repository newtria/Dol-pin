import type { ConfigContext, ExpoConfig } from 'expo/config';

function releaseUrl(key: string): void {
  try {
    const url = new URL(process.env[key] ?? '');
    if (url.protocol !== 'https:' || url.username || url.password ||
      /localhost|127\.|0\.0\.0\.0|example\.|your-project/i.test(url.hostname)) throw new Error();
  } catch { throw new Error(`Configure a production HTTPS URL for ${key}.`); }
}

export default ({ config }: ConfigContext): ExpoConfig => {
  const release = process.env.DOLPIN_RELEASE === '1';
  const bundle = process.env.DOLPIN_IOS_BUNDLE_IDENTIFIER;
  const androidPackage = process.env.DOLPIN_ANDROID_PACKAGE;
  const projectId = process.env.EXPO_PUBLIC_EAS_PROJECT_ID;
  const googleServicesFile = process.env.DOLPIN_GOOGLE_SERVICES_FILE;
  if (release) {
    if (!bundle || !/^[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z][A-Za-z0-9-]*)+$/.test(bundle) ||
      !androidPackage || !/^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+$/.test(androidPackage) ||
      [bundle, androidPackage].some(value => /preview|example|placeholder/i.test(value))) {
      throw new Error('Configure valid production iOS and Android application identifiers.');
    }
    if (!projectId || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(projectId)) {
      throw new Error('Configure a valid EAS project ID.');
    }
    for (const key of ['EXPO_PUBLIC_SUPABASE_URL', 'EXPO_PUBLIC_TERMS_URL', 'EXPO_PUBLIC_PRIVACY_URL']) releaseUrl(key);
    const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
    if (!anonKey || /your-|replace_me|placeholder/i.test(anonKey)) throw new Error('Configure the Supabase public key.');
    if (!anonKey.startsWith('sb_publishable_')) {
      try {
        const claims = JSON.parse(Buffer.from(anonKey.split('.')[1], 'base64url').toString('utf8'));
        if (claims.role !== 'anon') throw new Error();
      } catch { throw new Error('The mobile bundle must use a Supabase public key, never a server secret.'); }
    }
    if (process.env.EAS_BUILD_PLATFORM === 'android' && !googleServicesFile) {
      throw new Error('Configure DOLPIN_GOOGLE_SERVICES_FILE for Android push delivery.');
    }
  }
  return {
    ...config,
    name: 'dol-pin',
    slug: 'dol-pin',
    ios: { ...config.ios, bundleIdentifier: release ? bundle : 'app.dolpin.preview' },
    android: {
      ...config.android,
      package: release ? androidPackage : 'app.dolpin.preview',
      ...(googleServicesFile ? { googleServicesFile } : {}),
    },
    extra: { ...config.extra, ...(projectId ? { eas: { projectId } } : {}) },
  };
};

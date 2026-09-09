const fs = require('node:fs');
const path = require('node:path');
const {getDefaultConfig} = require('expo/metro-config');
const root = path.resolve(__dirname, '../..');
const modules = fs.realpathSync(path.join(root, 'node_modules'));
const config = getDefaultConfig(__dirname);
config.watchFolders = [...new Set([root, path.dirname(modules), modules, ...(config.watchFolders ?? [])])];
config.resolver.nodeModulesPaths = [modules, path.join(root, 'node_modules')];
config.resolver.extraNodeModules = {
  ...config.resolver.extraNodeModules,
  '@dolpin/contracts': path.join(root, 'packages/contracts'),
  '@dolpin/api-client': path.join(root, 'packages/api-client'),
};
module.exports = config;

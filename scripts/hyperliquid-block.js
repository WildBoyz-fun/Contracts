#!/usr/bin/env node
/* eslint-disable no-console */

const { spawnSync } = require('child_process');

const size = process.argv[2];
const allowed = new Set(['big', 'small']);

if (!allowed.has(size)) {
  console.error('Usage: node scripts/hyperliquid-block.js <big|small>');
  process.exit(1);
}

const privateKey = process.env.HYPERLIQUID_PRIVATE_KEY || process.env.PRIVATE_KEY;

if (!privateKey) {
  console.error('HYPERLIQUID_PRIVATE_KEY (or PRIVATE_KEY) is not set in the environment.');
  process.exit(1);
}

const args = [
  '@layerzerolabs/hyperliquid-composer',
  'set-block',
  '--size',
  size,
  '--network',
  'mainnet',
  '--private-key',
  privateKey,
];

const result = spawnSync('npx', args, {
  stdio: 'inherit',
  shell: true,
});

if (result.error) {
  console.error(result.error);
  process.exit(1);
}

process.exit(result.status ?? 0);

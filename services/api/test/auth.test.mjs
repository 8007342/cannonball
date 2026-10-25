import assert from 'node:assert/strict';
import test from 'node:test';
import { SignJWT, generateKeyPair } from 'jose';
import { verifyGoogle } from '../src/auth.mjs';

const { privateKey, publicKey } = await generateKeyPair('RS256');
const other = await generateKeyPair('RS256');
const audience = 'cannonball-client'; const nonce = 'browser-nonce';
async function token(overrides = {}, key = privateKey) {
  return new SignJWT({ sub: 'private-google-subject', nonce, iss: 'https://accounts.google.com', aud: audience, iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 300, ...overrides }).setProtectedHeader({ alg: 'RS256' }).sign(key);
}
test('Google verification requires trusted signature, audience, issuer, expiry and bound nonce', async () => {
  assert.equal(await verifyGoogle(await token(), audience, nonce, publicKey), 'private-google-subject');
  for (const claims of [{ aud: 'other' }, { aud: [audience, 'other'] }, { azp: 'other' }, { iss: 'https://evil.example' }, { exp: 1 }, { nonce: 'stolen' }, { sub: '' }, { exp: undefined }, { iat: undefined }]) {
    await assert.rejects(verifyGoogle(await token(claims), audience, nonce, publicKey), /invalid_credential/);
  }
  await assert.rejects(verifyGoogle(await token({}, other.privateKey), audience, nonce, publicKey), /invalid_credential/);
  await assert.rejects(verifyGoogle('not.a.jwt', audience, nonce, publicKey), /invalid_credential/);
});

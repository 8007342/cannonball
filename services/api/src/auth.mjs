import { createRemoteJWKSet, jwtVerify } from 'jose';
import { ApiError, requireCondition } from './rules.mjs';

export const SESSION_COOKIE = '__Host-cannonball_session';
export const CHALLENGE_COOKIE = '__Host-cannonball_challenge';
export const SESSION_MS = 30 * 86400000;
export const CHALLENGE_MS = 5 * 60000;
const googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));

export async function verifyGoogle(credential, audience, nonce, keys = googleKeys) {
  try {
    requireCondition(typeof credential === 'string' && credential.length <= 12000, 'invalid_credential', 401);
    const { payload } = await jwtVerify(credential, keys, {
      algorithms: ['RS256'], audience,
      issuer: ['https://accounts.google.com', 'accounts.google.com'],
      requiredClaims: ['sub', 'exp', 'iat', 'nonce'], maxTokenAge: '2h', clockTolerance: 5,
    });
    requireCondition(payload.aud === audience && (!payload.azp || payload.azp === audience), 'invalid_credential', 401);
    requireCondition(typeof payload.sub === 'string' && payload.sub.length > 0 && payload.sub.length <= 255 && payload.nonce === nonce, 'invalid_credential', 401);
    return payload.sub;
  } catch { throw new ApiError(401, 'invalid_credential'); }
}
export function randomToken() {
  return Array.from(crypto.getRandomValues(new Uint8Array(32)), x => x.toString(16).padStart(2, '0')).join('');
}
export async function hashToken(token) {
  if (!token) return '';
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token))), x => x.toString(16).padStart(2, '0')).join('');
}
export function readCookie(request, name) {
  const matches = (request.headers.get('cookie') ?? '').split(';').map(x => x.trim()).filter(x => x.startsWith(`${name}=`));
  if (matches.length !== 1) return '';
  const token = matches[0].slice(name.length + 1);
  return /^[a-f0-9]{64}$/.test(token) ? token : '';
}
export function cookie(name, token, seconds) {
  return `${name}=${token}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=${seconds}`;
}

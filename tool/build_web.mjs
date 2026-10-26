// Publisher entry point: use the forge SDK, or bootstrap a verified pinned SDK
// on a clean Linux build host. No credentials or remote deployment are involved.
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createReadStream, createWriteStream } from 'node:fs';
import { access, mkdir, rm } from 'node:fs/promises';
import { tmpdir, arch, platform } from 'node:os';
import { join } from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

const version = '3.47.7';
function run(command, args) {
  const result = spawnSync(command, args, { stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} exited ${result.status}`);
}
let flutter = process.env.FLUTTER_BIN || 'flutter';
const installed = spawnSync(flutter, ['--version'], { encoding: 'utf8' });
if (installed.error?.code === 'ENOENT' && !process.env.FLUTTER_BIN) {
  if (platform() !== 'linux') throw new Error('Install Flutter 3.47.7 or set FLUTTER_BIN on this platform.');
  const cache = process.env.CANNONBALL_FLUTTER_CACHE || join(tmpdir(), `cannonball-flutter-${version}-${arch()}`);
  flutter = join(cache, 'flutter', 'bin', 'flutter');
  let cached = true;
  try { await access(flutter); } catch { cached = false; }
  if (!cached) {
    const base = 'https://storage.googleapis.com/flutter_infra_release/releases';
    const manifestResponse = await fetch(`${base}/releases_linux.json`);
    if (!manifestResponse.ok) throw new Error(`Flutter manifest: ${manifestResponse.status}`);
    const manifest = await manifestResponse.json();
    const sdkArch = arch() === 'arm64' ? 'arm64' : 'x64';
    const release = manifest.releases.find(r => r.version === version && r.dart_sdk_arch === sdkArch);
    if (!release?.sha256 || !release.archive || release.archive.includes('..')) throw new Error(`No verified Flutter ${version}/${sdkArch} archive in official manifest.`);
    await mkdir(cache, { recursive: true });
    const archive = join(cache, 'sdk.tar.xz');
    console.log(`Preparing Flutter ${version} from the official release archive…`);
    const response = await fetch(`${base}/${release.archive}`);
    if (!response.ok || !response.body) throw new Error(`Flutter archive: ${response.status}`);
    await pipeline(Readable.fromWeb(response.body), createWriteStream(archive));
    const hash = createHash('sha256');
    for await (const chunk of createReadStream(archive)) hash.update(chunk);
    if (hash.digest('hex') !== release.sha256) {
      await rm(archive, { force: true });
      throw new Error('Flutter archive checksum mismatch.');
    }
    run('tar', ['-xf', archive, '-C', cache]);
    await rm(archive, { force: true });
  }
} else if (installed.error || installed.status !== 0) {
  throw installed.error || new Error('Configured Flutter SDK could not start.');
}
run(flutter, ['pub', 'get']);
run(flutter, ['build', 'web', '--release']);

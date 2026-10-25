// Local preview MIME workaround only. The preview currently serves .mjs as
// text/plain; an unchanged byte-copy with .js is served as application/javascript.
// A production server should serve .mjs correctly instead.
import fs from 'node:fs';
const directory = new URL('../build/web/bench/wasm/', import.meta.url);
const bootstrap = new URL('flutter_bootstrap.js', directory);
const oldPath = '"jsSupportRuntimePath":"main.dart.mjs"';
const newPath = '"jsSupportRuntimePath":"main.dart.runtime.js"';
const text = fs.readFileSync(bootstrap, 'utf8');
if (!text.includes(oldPath) && !text.includes(newPath)) {
  throw new Error('Unexpected Flutter bootstrap; review before modifying it.');
}
fs.copyFileSync(new URL('main.dart.mjs', directory), new URL('main.dart.runtime.js', directory));
fs.writeFileSync(bootstrap, text.replace(oldPath, newPath));

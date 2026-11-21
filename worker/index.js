/**
 * Front Worker for the Godot web export.
 *
 * Cloudflare Workers static assets cap every file at 25 MiB, but Godot's release
 * `index.wasm` is ~38 MiB. `scripts/cf-build.sh` therefore splits it into
 * `index.wasm.part0`, `index.wasm.part1`, ... plus a small
 * `index.wasm.parts.json` manifest. This Worker is only invoked for
 * `/index.wasm` (see `assets.run_worker_first` in wrangler.jsonc), where it
 * streams the parts back in order as one `application/wasm` response, which is
 * exactly what the Godot loader expects.
 *
 * Changes to this file only take effect after the next deploy.
 */

const WASM_PATH = '/index.wasm';
const MANIFEST_PATH = '/index.wasm.parts.json';

const textError = (message, status) =>
	new Response(`${message}\n`, {
		status,
		headers: { 'content-type': 'text/plain; charset=utf-8' },
	});

export default {
	async fetch(request, env) {
		const url = new URL(request.url);

		// Everything except the wasm is served straight from static assets.
		if (url.pathname !== WASM_PATH) {
			return env.ASSETS.fetch(request);
		}

		const manifestResponse = await env.ASSETS.fetch(new URL(MANIFEST_PATH, url), {
			method: 'GET',
		});
		if (!manifestResponse.ok) {
			return textError(
				`${MANIFEST_PATH} is missing from this deployment. ` +
					'Rebuild with `bash ./scripts/cf-build.sh` before deploying.',
				500,
			);
		}

		let manifest;
		try {
			manifest = await manifestResponse.json();
		} catch {
			return textError(`${MANIFEST_PATH} is not valid JSON.`, 500);
		}

		const count = manifest?.count;
		if (!Number.isInteger(count) || count < 1) {
			return textError(`${MANIFEST_PATH} has an invalid part count.`, 500);
		}

		const headers = new Headers({
			'content-type': 'application/wasm',
			'cache-control': 'no-cache',
			'x-content-type-options': 'nosniff',
			vary: 'accept-encoding',
		});
		if (manifest.etag) {
			headers.set('etag', manifest.etag);
			if (request.headers.get('if-none-match') === manifest.etag) {
				return new Response(null, { status: 304, headers });
			}
		}

		if (request.method === 'HEAD') {
			if (manifest.size) {
				headers.set('content-length', String(manifest.size));
			}
			return new Response(null, { status: 200, headers });
		}

		// Fetch the parts up front (bodies stream lazily) so a missing piece
		// fails fast with a clear error instead of a truncated wasm download.
		const parts = [];
		for (let i = 0; i < count; i++) {
			const partPath = `/index.wasm.part${i}`;
			const part = await env.ASSETS.fetch(new URL(partPath, url), { method: 'GET' });
			if (!part.ok || !part.body) {
				return textError(`Missing ${partPath} in this deployment.`, 500);
			}
			parts.push(part.body);
		}

		const body = new ReadableStream({
			async start(controller) {
				try {
					for (const part of parts) {
						const reader = part.getReader();
						for (;;) {
							const { done, value } = await reader.read();
							if (done) {
								break;
							}
							controller.enqueue(value);
						}
					}
					controller.close();
				} catch (err) {
					controller.error(err);
				}
			},
		});

		return new Response(body, { status: 200, headers });
	},
};

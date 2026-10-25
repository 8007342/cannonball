// Deployment foundation only. Authentication, saves and ranking are future work.
const json = (body, status = 200, headers = {}) => new Response(JSON.stringify(body), {
  status,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
    ...headers,
  },
});

export default {
  async fetch(request) {
    const { pathname } = new URL(request.url);
    if (pathname === '/api/health') {
      if (request.method !== 'GET') {
        return json({ error: 'method_not_allowed' }, 405, { allow: 'GET' });
      }
      return json({ service: 'cannonball-api', status: 'ok', phase: 'foundation' });
    }
    return json({ error: 'not_found' }, 404);
  },
};

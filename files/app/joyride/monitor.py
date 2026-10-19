#!/usr/bin/env python3
"""Bounded anonymous application probes; no credentials, logs or member data."""
import json
import re
import sys
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def probe(open_url=None):
    open_url = open_url or urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect()).open
    for path, expected in (('/health/ready', 'ready'), ('/api/csrf', 'csrf'),
                           ('/maps/current', 'map'), ('/', 'html')):
        request = urllib.request.Request('http://joyride-test-web.test.svc:8000' + path,
                                         headers={'Host': 'joyride-test.eyrie'})
        with open_url(request, timeout=10) as response:
            if response.status != 200:
                raise ValueError('status')
            body = response.read(65537)
            if len(body) > 65536:
                raise ValueError('oversized')
            if expected != 'html':
                value = json.loads(body)
                if not isinstance(value, dict) or not value:
                    raise ValueError('json')
                if expected == 'ready' and value.get('status') != 'ready':
                    raise ValueError('not_ready')
                if expected == 'csrf' and not re.fullmatch(r'[a-zA-Z0-9]{64}', value.get('csrf_token', '')):
                    raise ValueError('csrf')
                if expected == 'map' and (not re.fullmatch(r'[0-9a-f]{64}', value.get('sha256', ''))
                                          or not value.get('url', '').startswith('/maps/')):
                    raise ValueError('map')
            elif 'text/html' not in response.headers.get('Content-Type', '') or b'<html' not in body.lower():
                raise ValueError('html')
    return 'ready, session, basemap and home passed'


if __name__ == '__main__':
    try:
        print('Joyride TEST monitor: ' + probe())
    except Exception:
        print('Joyride TEST application probe failed', file=sys.stderr)
        sys.exit(1)

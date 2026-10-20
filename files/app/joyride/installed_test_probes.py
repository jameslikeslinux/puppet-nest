"""HTTPS checks for the trusted producer, using exact disposable TEST fixtures.

No curated/private route inputs, provider actions, waiver assent or public media.
Credentials and session bytes stay in process memory and are never reported.
"""
import http.cookiejar
import json
import re
import subprocess
import uuid
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, HTTPCookieProcessor, Request, build_opener

ORIGIN = "https://joyride-test.eyrie"
CHECKS = ["https_readiness", "session_csrf", "disabled_billing",
          "private_route_photo_gpx", "photo_only", "basemap_range"]


def require(value):
    if not value:
        raise ValueError("installed_test_probe_failed")


def manage(code):
    result = subprocess.run([
        "kubectl", "-n", "test", "exec", "-i", "deployment/joyride-test", "-c", "worker",
        "--", "python", "manage.py", "shell", "-c", "import sys; exec(sys.stdin.read())"],
        input=code, text=True, capture_output=True, timeout=60, check=False)
    require(result.returncode == 0 and len(result.stdout) < 65536)
    lines = [line[6:] for line in result.stdout.splitlines() if line.startswith("PROBE:")]
    require(len(lines) == 1)
    return json.loads(lines[0])


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("probe_redirect_denied")


class Client:
    def __init__(self, session=None):
        self.cookies = http.cookiejar.CookieJar()
        if session:
            self.cookies.set_cookie(http.cookiejar.Cookie(
                version=0, name="joyride_session", value=session, port=None, port_specified=False,
                domain="joyride-test.eyrie", domain_specified=False, domain_initial_dot=False,
                path="/", path_specified=True, secure=True, expires=None, discard=True,
                comment=None, comment_url=None, rest={"HttpOnly": ""}))
        self.opener = build_opener(NoRedirect(), HTTPCookieProcessor(self.cookies))

    def request(self, path, payload=None, csrf=None, byte_range=False):
        # Paths come from fixed probes or the validated single basemap path.
        require(path.startswith("/") and not path.startswith("//"))
        headers = {}
        if payload is not None:
            headers["Content-Type"] = "application/json"
        if csrf:
            headers.update({"X-CSRFToken": csrf, "Origin": ORIGIN, "Referer": ORIGIN + "/"})
        if byte_range:
            headers["Range"] = "bytes=0-7"
        request = Request(ORIGIN + path, headers=headers,
                          data=json.dumps(payload).encode() if payload is not None else None)
        try:
            response = self.opener.open(request, timeout=20)
        except HTTPError as error:
            response = error
        with response:
            body = response.read(1048577)
            require(len(body) <= 1048576)
            return response.status, body, response.headers

    def json(self, path, **kwargs):
        status, body, _ = self.request(path, **kwargs)
        return status, json.loads(body)


COMMON = '''
import json, shutil
from datetime import timedelta
from django.conf import settings
from django.utils import timezone
from django.contrib.sessions.backends.db import SessionStore
from django.contrib.sessions.models import Session
from django.db import transaction
from core.models import Member, Route, Media, WaiverAcceptance, Checkout, Deployment
from core.media import process_media
assert settings.RUNTIME_ENV == 'test' and settings.STRIPE_MODE == 'disabled' and not settings.MAIL_ENABLED
'''


def run(delivery_id, digest, head, pipeline_url):
    tag = "installed-proof-" + uuid.uuid4().hex
    email = tag + "@example.invalid"
    session_id = uuid.uuid4().hex
    photo_id = str(uuid.uuid4())
    common = COMMON + f"tag = {tag!r}\nemail = {email!r}\nsession_id = {session_id!r}\nphoto_id = {photo_id!r}\n"
    manage(common + f'''
d = Deployment.objects.get(pk={delivery_id!r}, environment='test', state='succeeded', error_code='')
assert d.artifact.digest == {digest!r} and d.artifact.source_head == {head!r}
assert d.artifact.pipeline_url == {pipeline_url!r} and d.artifact.test_passed
assert not Deployment.objects.filter(state__in=['queued', 'running']).exists()
assert not Member.objects.filter(email=email).exists()
assert not Route.objects.filter(slug=tag).exists()
assert not (settings.PRIVATE_ROOT/tag).exists()
assert not Session.objects.filter(session_key=session_id).exists()
assert not Media.objects.filter(pk=photo_id).exists()
assert not (settings.PRIVATE_ROOT/'derivatives'/photo_id).exists()
print('PROBE:'+json.dumps({{'preflight':True}}))
''')
    # Cleanup also runs when setup partly fails. Unique identifiers fence deletion.
    seed = None
    try:
        seed = manage(common + '''
from PIL import Image
folder = settings.PRIVATE_ROOT/tag
folder.mkdir(mode=0o700)
(folder/'route.gpx').write_bytes(b'<gpx version="1.1"><trk><name>Engineering synthetic TEST fixture</name></trk></gpx>')
Image.new('RGB', (4,4), color=(20,40,60)).save(folder/'original.jpg', 'JPEG')
with transaction.atomic():
    m = Member.objects.create(email=email, verified_at=timezone.now())
    r = Route.objects.create(slug=tag, available=True, gpx_path=tag+'/route.gpx', member_data={'fixture':True})
    photo = Media.objects.create(id=photo_id, route=r, kind='photo', exposure='member', original_path=tag+'/original.jpg')
    process_media(photo.pk)
    video = Media.objects.create(route=r, kind='video', exposure='public', ready=True, original_path=tag+'/absent.mp4', derivative_path=tag+'/absent.mp4')
    expiry = timezone.now()+timedelta(minutes=10)
    Session.objects.create(session_key=session_id, expire_date=expiry,
        session_data=SessionStore().encode({'member_id':m.pk,'verified_until':expiry.timestamp()}))
print('PROBE:'+json.dumps({'session':session_id,'photo':str(photo.pk),'video':str(video.pk)}))
''')
        anon, member = Client(), Client(seed["session"])
        require(anon.json("/health/ready") == (200, {"status": "ready"}))
        status, me = member.json("/api/me")
        require(status == 200 and me["email"] == email and me["membership_status"] == "none"
                and me["waiver_current"] is False)
        status, csrf = member.json("/api/csrf")
        require(status == 200 and re.fullmatch(r"[A-Za-z0-9]{64}", csrf.get("csrf_token", "")))
        csrf = csrf["csrf_token"]
        status, acsrf = anon.json("/api/csrf")
        require(status == 200)
        require(me["billing"] == {"mode": "disabled", "checkout_available": False, "portal_available": False})
        for path in ("/api/billing/checkout", "/api/billing/portal"):
            require(member.json(path, payload={}, csrf=csrf) == (503, {"error": "payments_disabled"}))
            require(member.request(path, payload={})[0] == 403)
            require(anon.request(path, payload={}, csrf=acsrf["csrf_token"])[0] == 401)
        require(anon.json("/stripe/webhook", payload={}) == (503, {"error": "payments_disabled"}))
        paths = ["/api/routes/" + tag, "/api/routes/" + tag + "/gpx",
                 "/api/media/" + seed["photo"] + "/file"]
        for path in paths:
            require(anon.request(path)[0] == 401 and member.request(path)[0] == 403)
        manage(common + '''
m = Member.objects.get(email=email)
m.subscription_status = 'active'
m.entitled_until = timezone.now()+timedelta(minutes=10)
m.save(update_fields=['subscription_status','entitled_until'])
print('PROBE:'+json.dumps({'synthetic_entitlement':True}))
''')
        status, route = member.json(paths[0])
        require(status == 200 and route["slug"] == tag and route["data"] == {"fixture": True}
                and route["gpx_url"] == paths[1] and len(route["media"]) == 1
                and route["media"][0]["id"] == seed["photo"] and route["media"][0]["kind"] == "photo")
        status, gpx, _ = member.request(paths[1])
        require(status == 200 and b'Engineering synthetic TEST fixture' in gpx)
        status, photo, headers = member.request(paths[2], byte_range=True)
        require(status == 206 and len(photo) == 8 and photo.startswith(b'\xff\xd8')
                and headers.get("Content-Range", "").startswith("bytes 0-7/"))
        require(anon.request("/media/public/" + seed["photo"])[0] == 404)
        for path in ("/api/media/" + seed["video"] + "/file", "/api/media/" + seed["video"] + "/poster",
                     "/media/public/" + seed["video"], "/assets/clip-test-cathedral-pan.mp4"):
            require(member.request(path)[0] == 404)
        status, home, _ = anon.request("/")
        require(status == 200 and b"<html" in home.lower() and b"<video" not in home.lower()
                and b"clip-test-cathedral-pan.mp4" not in home)
        status, basemap = anon.json("/maps/current")
        require(status == 200 and basemap["license"] == "ODbL-1.0"
                and "OpenStreetMap" in basemap["attribution"]
                and re.fullmatch(r"[0-9a-f]{64}", basemap["sha256"])
                and re.fullmatch(r"/maps/[A-Za-z0-9_-]+\.pmtiles", basemap["url"]))
        status, chunk, headers = anon.request(basemap["url"], byte_range=True)
        require(status == 206 and chunk == b"PMTiles\x03" and headers.get("ETag") == '"' + basemap["sha256"] + '"'
                and headers.get("Content-Range", "").startswith("bytes 0-7/"))
        require(member.json("/api/auth/logout", payload={}, csrf=csrf) == (200, {"status": "signed_out"}))
        require(member.request("/api/me")[0] == 401)
    finally:
        # No global count assumptions: do not delete unrelated members or sessions.
        cleanup = manage(common + '''
m = Member.objects.filter(email=email).first()
if m:
    assert not WaiverAcceptance.objects.filter(member=m).exists()
    assert not Checkout.objects.filter(member=m).exists()
    assert m.stripe_customer is None and m.stripe_subscription is None
    m.delete()
r = Route.objects.filter(slug=tag).first()
if r:
    r.delete()
folder = settings.PRIVATE_ROOT/'derivatives'/photo_id
if folder.exists():
    shutil.rmtree(folder)
Session.objects.filter(session_key=session_id).delete()
folder = settings.PRIVATE_ROOT/tag
if folder.exists():
    shutil.rmtree(folder)
assert not Member.objects.filter(email=email).exists()
assert not Route.objects.filter(slug=tag).exists()
assert not (settings.PRIVATE_ROOT/tag).exists()
assert not Session.objects.filter(session_key=session_id).exists()
assert not Media.objects.filter(pk=photo_id).exists()
assert not (settings.PRIVATE_ROOT/'derivatives'/photo_id).exists()
print('PROBE:'+json.dumps({'exact_cleanup':True}))
''')
        require(cleanup == {"exact_cleanup": True})
    return list(CHECKS)

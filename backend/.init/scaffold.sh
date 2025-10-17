#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/tic-tac-toe-web-app-30481-30497/backend"
cd "$WORKSPACE"
# load workspace env
[ -f "$WORKSPACE/.workspace_env.sh" ] && . "$WORKSPACE/.workspace_env.sh"
PY="$WORKSPACE"/.venv/bin/python
# create venv if missing
if [ ! -d "$WORKSPACE/.venv" ]; then python3 -m venv "$WORKSPACE/.venv"; fi
# upgrade pip
$PY -m pip install --upgrade pip setuptools >/dev/null
# ensure .env.local with SECRET_KEY
if [ ! -f "$WORKSPACE/.env.local" ]; then
  cat > "$WORKSPACE/.env.local" <<'ENV'
SECRET_KEY=dev-secret-key
ENV
  chmod 600 "$WORKSPACE/.env.local"
fi
# ensure workspace env wrapper
cat > "$WORKSPACE/.workspace_env.sh" <<'SH'
#!/usr/bin/env bash
# activate venv and load .env.local
export WORKON_HOME="$WORKSPACE/.venv"
. "$WORKSPACE"/.venv/bin/activate
[ -f "$WORKSPACE/.env.local" ] && set -a && . "$WORKSPACE/.env.local" && set +a
SH
chmod +x "$WORKSPACE/.workspace_env.sh"
# ensure Django installed
$PY -m pip show Django >/dev/null 2>&1 || $PY -m pip install "Django>=4.2,<5" >> "$WORKSPACE/pip_install.log" 2>&1
# create project if missing
if [ ! -f "$WORKSPACE/manage.py" ] || [ ! -d "$WORKSPACE/project" ]; then
  $PY -m django startproject project .
fi
# create app webapp if missing
if [ ! -d "$WORKSPACE/webapp" ]; then
  $PY manage.py startapp webapp >/dev/null || true
fi
# minimal view and urls
if [ ! -f "$WORKSPACE/webapp/views.py" ]; then
  cat > "$WORKSPACE/webapp/views.py" <<'PY'
from django.http import HttpResponse

def index(request):
    return HttpResponse('OK')
PY
fi
if [ ! -f "$WORKSPACE/webapp/urls.py" ]; then
  cat > "$WORKSPACE/webapp/urls.py" <<'PY'
from django.urls import path
from .views import index
urlpatterns = [path('', index)]
PY
fi
# safe edits
$PY - <<'PY'
from pathlib import Path
p=Path('project/settings.py')
s=p.read_text()
changed=False
if 'DEBUG = True' not in s:
    if 'DEBUG = False' in s:
        s=s.replace('DEBUG = False','DEBUG = True')
    else:
        s = 'DEBUG = True\n' + s
    changed=True
import re
m=re.search(r'ALLOWED_HOSTS\s*=\s*(\[.*?\])',s,flags=re.S)
if m:
    arr=m.group(1)
    if "'*'" not in arr and '"*"' not in arr:
        s=re.sub(r'ALLOWED_HOSTS\s*=\s*\[.*?\]','ALLOWED_HOSTS = ["*"]',s,flags=re.S)
        changed=True
else:
    s += '\nALLOWED_HOSTS = ["*"]\n'
    changed=True
if 'webapp' not in s:
    s=re.sub(r'INSTALLED_APPS\s*=\s*\[', "INSTALLED_APPS = [\n    'webapp',", s, count=1)
    changed=True
if changed:
    p.write_text(s)
print('ok')
PY
# append include
$PY - <<'PY'
from pathlib import Path
p=Path('project/urls.py')
s=p.read_text()
if "include('webapp.urls')" not in s and 'include("webapp.urls")' not in s:
    if 'urlpatterns' in s:
        if 'from django.urls import include' not in s:
            s=s.replace('from django.urls import path', 'from django.urls import path, include')
        s=s.replace('urlpatterns = [', 'urlpatterns = [\n    path("", include("webapp.urls")),',1)
    else:
        s='from django.contrib import admin\nfrom django.urls import path, include\n\nurlpatterns = [path("admin/", admin.site.urls), path("", include("webapp.urls"))]\n'
    p.write_text(s)
print('ok')
PY
date -u > "$WORKSPACE/.setup_scaffold_stamp"

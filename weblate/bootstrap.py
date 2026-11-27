#!/usr/bin/env python3

from __future__ import annotations

import glob
import json
import os
import re
import subprocess
import sys
import time
import uuid
from http.client import HTTPException
from pathlib import Path
from urllib import error, request

ACTIONS = ("init", "pull", "push", "deploy-keys")
USAGE = "uso: python3 weblate/bootstrap.py init|pull|push|deploy-keys  (WEBLATE_URL e WEBLATE_API_TOKEN no ambiente)"

READY_TIMEOUT = 600
DEPLOY_KEY_TITLE = "Weblate MeasureSoftGram"
SSH_DIR = "/app/data/ssh"
ENSURE_KEY_SCRIPT = r'''
key="$1/deploy-$2"
[ -f "$key" ] || ssh-keygen -q -t ed25519 -N "" -C "Weblate MeasureSoftGram ($2)" -f "$key"
grep -qx "Host $2" "$1/config" 2>/dev/null ||
  printf '\nHost %s\n  HostName github.com\n  User git\n  IdentityFile %s\n' "$2" "$key" >> "$1/config"
cat "$key.pub"
'''
IMPORT_TIMEOUT = 120

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PUBLISH_OPTIONS = ("push", "push_branch")
REPOSITORY_OPTIONS = {
    "vcs", "branch", "push", "push_branch", "push_on_commit", "commit_pending_age", "merge_style",
    "commit_message", "add_message", "delete_message", "merge_message", "addon_message",
}


class ApiError(Exception):
    def __init__(self, status: int, body: str):
        super().__init__(f"HTTP {status}: {body[:500]}")
        self.status = status


class Weblate:
    def __init__(self, url: str, token: str):
        self.base = url.rstrip("/") + "/api/"
        self.token = token

    def _call(self, method: str, path: str, data: bytes | None, content_type: str | None):
        url = path if path.startswith("http") else self.base + path.lstrip("/")
        req = request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Token {self.token}")
        req.add_header("Accept", "application/json")
        if content_type:
            req.add_header("Content-Type", content_type)
        try:
            with request.urlopen(req) as resp:
                raw = resp.read().decode()
        except error.HTTPError as exc:
            raise ApiError(exc.code, exc.read().decode(errors="replace")) from None
        return json.loads(raw) if raw else None

    def get(self, path: str):
        return self._call("GET", path, None, None)

    def exists(self, path: str) -> bool:
        try:
            self.get(path)
        except ApiError as exc:
            if exc.status == 404:
                return False
            raise
        return True

    def send(self, method: str, path: str, payload: dict):
        return self._call(method, path, json.dumps(payload).encode(), "application/json")

    def upload(self, path: str, fields: dict[str, str], filename: str, content: bytes):
        boundary = uuid.uuid4().hex
        parts = []
        for key, value in fields.items():
            parts.append(
                f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode()
            )
        parts.append(
            (
                f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{filename}"\r\n'
                "Content-Type: text/csv\r\n\r\n"
            ).encode()
            + content
            + b"\r\n"
        )
        parts.append(f"--{boundary}--\r\n".encode())
        return self._call("POST", path, b"".join(parts), f"multipart/form-data; boundary={boundary}")

    def all_pages(self, path: str) -> list:
        items, page = [], self.get(path)
        while True:
            items.extend(page["results"])
            if not page.get("next"):
                return items
            page = self.get(page["next"])


def load(name: str) -> dict:
    return json.loads((HERE / name).read_text(encoding="utf-8"))


def publishing_enabled() -> bool:
    return os.environ.get("WEBLATE_PUBLISH", "") == "1"


def local_only(comp: dict) -> dict:
    return {**comp, **{k: "" for k in PUBLISH_OPTIONS}, "vcs": "git", "push_on_commit": False}


def expand_components(spec: dict, publish: bool = True) -> list[dict]:
    defaults, repos = spec["defaults"], spec["repositories"]
    result = []

    def add(item: dict, repository: str) -> None:
        repo = repos[repository]
        comp = {**defaults, **item, "repo": repo["repo"], "_addons": repo["addons"]}
        if "push" in repo:
            comp["push"] = repo["push"]
        result.append(comp if publish else local_only(comp))

    for comp in spec["components"]:
        if "namespaces_from" not in comp:
            add(dict(comp), comp["repository"])
            continue
        namespaces = sorted(Path(p).stem for p in glob.glob(str(ROOT / comp["namespaces_from"])))
        if not namespaces:
            print(f"!! nenhum namespace em {comp['namespaces_from']} (submodulo inicializado?)")
            continue
        main = comp.get("main_namespace", namespaces[0])
        if main in namespaces:
            namespaces.remove(main)
        else:
            print(f"!! namespace principal {main} nao existe em {comp['namespaces_from']}; usando {namespaces[0]}")
            main = namespaces.pop(0)
        for ns in [main, *namespaces]:
            item = {
                key: (value.format(namespace=ns) if isinstance(value, str) else value)
                for key, value in comp.items()
                if key not in ("namespaces_from", "main_namespace")
            }
            add(item, comp["repository"])
    return result


def ensure_project(api: Weblate, project: dict) -> str:
    slug = project["slug"]
    if not api.exists(f"projects/{slug}/"):
        api.send("POST", "projects/", {"name": project["name"], "slug": slug, "web": project["web"]})
        print(f"++ projeto {slug}")
    settings = {
        key: project[key]
        for key in ("instructions", "language_aliases", "use_shared_tm", "contribute_shared_tm", "web")
        if key in project
    }
    api.send("PATCH", f"projects/{slug}/", settings)
    print(f"== projeto {slug}: configuracoes aplicadas")
    return slug


def loaded_translations(api: Weblate, project: str, component: str) -> list:
    deadline = time.monotonic() + IMPORT_TIMEOUT
    while True:
        translations = api.all_pages(f"components/{project}/{component}/translations/")
        if translations or time.monotonic() >= deadline:
            return translations
        time.sleep(3)


def normalize_language(code: str) -> str:
    return code.replace("-", "_").lower()


def ensure_translation(api: Weblate, project: str, component: str, language: str) -> None:
    translations = loaded_translations(api, project, component)
    codes = {t["language_code"] for t in translations} | {t["language"]["code"] for t in translations}
    wanted = normalize_language(language)
    if any(normalize_language(code) == wanted for code in codes):
        return
    try:
        api.send("POST", f"components/{project}/{component}/translations/", {"language_code": language})
        print(f"   ++ idioma {language}")
    except ApiError as exc:
        print(f"   !! idioma {language} nao criado ({exc})")


def ensure_addons(api: Weblate, project: str, component: str, addons: list[dict]) -> None:
    urls = api.get(f"components/{project}/{component}/").get("addons", [])
    installed = {a["name"]: a for a in (api.get(u) for u in urls)}
    for addon in addons:
        current = installed.get(addon["name"])
        if current is None:
            api.send("POST", f"components/{project}/{component}/addons/", addon)
            print(f"   ++ addon {addon['name']}")
        elif current.get("configuration") != addon["configuration"]:
            api.send("PATCH", current["url"], {"configuration": addon["configuration"]})
            print(f"   == addon {addon['name']} reconfigurado")


def link_to_owner(comp: dict, project: str, owner: str) -> dict:
    linked = {k: v for k, v in comp.items() if k not in REPOSITORY_OPTIONS}
    linked["repo"] = f"weblate://{project}/{owner}"
    return linked


def ensure_components(api: Weblate, project: str) -> list[str]:
    created, skipped = [], []
    owners: dict[str, str] = {}
    publish = publishing_enabled()
    if not publish:
        print("!! WEBLATE_PUBLISH=0: componentes so leem o develop, sem push em weblate/translations")
    for comp in expand_components(load("components.json"), publish):
        addons = comp.pop("_addons")
        repository = comp.pop("repository")
        if repository in owners:
            comp, addons = link_to_owner(comp, project, owners[repository]), []
        slug = comp["slug"]
        path = f"components/{project}/{slug}/"
        try:
            if api.exists(path):
                settings = {k: v for k, v in comp.items() if k not in ("slug", "file_format", "repo")}
                api.send("PATCH", path, settings)
                print(f"== componente {slug}")
            else:
                api.send("POST", f"projects/{project}/components/", comp)
                print(f"++ componente {slug}")
            ensure_addons(api, project, slug, addons)
        except ApiError as exc:
            print(f"!! componente {slug} pulado: {exc}")
            skipped.append(slug)
            continue
        owners.setdefault(repository, slug)
        created.append(slug)
    if skipped:
        print(f"\nComponentes pulados (rode `make weblate-init` de novo depois do merge): {', '.join(skipped)}")
    return created


def ensure_glossary(api: Weblate, project: str, languages: list[str], csv_name: str) -> None:
    content = (HERE / csv_name).read_bytes()
    for language in languages:
        ensure_translation(api, project, "glossary", language)
        path = f"translations/{project}/glossary/{language}/file/"
        for method in ("add", "translate"):
            try:
                result = api.upload(path, {"method": method, "conflicts": "replace-translated"}, csv_name, content)
                print(f"== glossario {language} ({method}): {result.get('accepted', 0)} termos aplicados")
            except ApiError as exc:
                print(f"!! glossario {language} ({method}): {exc}")


def repository_operation(api: Weblate, project: str, operation: str) -> None:
    result = api.send("POST", f"projects/{project}/repository/", {"operation": operation})
    print(f"== {operation}: {result}")


def in_weblate(*args: str) -> str:
    cmd = ["docker", "compose", "exec", "-T", "weblate", *args]
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=True).stdout


def push_target(push: str) -> tuple[str, str] | None:
    match = re.fullmatch(r"git@([\w.-]+):([\w.-]+/[\w.-]+?)(?:\.git)?", push)
    return (match.group(1), match.group(2)) if match else None


def registered_keys(slug: str) -> set[str]:
    out = subprocess.run(
        ["gh", "api", f"repos/{slug}/keys", "--paginate", "-q", ".[].key"],
        capture_output=True, text=True, check=True,
    ).stdout
    return {" ".join(line.split()[:2]) for line in out.splitlines() if line}


def ensure_deploy_keys() -> int:
    in_weblate("weblate", "shell", "-c", 'from weblate.vcs.ssh import add_host_key; add_host_key(None, "github.com")')
    print("== host key do github.com confiada")
    failed = 0
    for name, repo in load("components.json")["repositories"].items():
        target = push_target(repo.get("push", ""))
        if target is None:
            print(f"!! {name}: push {repo.get('push')!r} nao e git@<alias>:<dono>/<repo>")
            failed += 1
            continue
        alias, slug = target
        public = in_weblate("sh", "-c", ENSURE_KEY_SCRIPT, "sh", SSH_DIR, alias).strip()
        material = " ".join(public.split()[:2])
        try:
            if material in registered_keys(slug):
                print(f"== {slug}: deploy key ja cadastrada ({alias})")
                continue
            subprocess.run(
                ["gh", "api", f"repos/{slug}/keys", "-f", f"title={DEPLOY_KEY_TITLE} ({alias})",
                 "-f", f"key={material}", "-F", "read_only=false"],
                capture_output=True, text=True, check=True,
            )
            print(f"++ {slug}: deploy key com escrita cadastrada ({alias})")
        except subprocess.CalledProcessError as exc:
            print(f"!! {slug}: deploy key nao cadastrada ({exc.stderr.strip()}; precisa de admin no repositorio)")
            print(f"   cadastre a mao, com escrita: {material}")
            failed += 1
    return 1 if failed else 0


def wait_until_ready(url: str) -> bool:
    deadline = time.monotonic() + READY_TIMEOUT
    while time.monotonic() < deadline:
        try:
            with request.urlopen(url.rstrip("/") + "/healthz/", timeout=5) as resp:
                if resp.status == 200:
                    return True
        except (error.URLError, HTTPException, OSError):
            pass
        print("aguardando o Weblate ficar pronto…")
        time.sleep(5)
    return False


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in ACTIONS:
        print(USAGE)
        return 2
    url, token = os.environ.get("WEBLATE_URL"), os.environ.get("WEBLATE_API_TOKEN")
    if not url or not token:
        print(USAGE)
        return 2
    api = Weblate(url, token)
    project = load("project.json")
    action = sys.argv[1]
    if not wait_until_ready(url):
        print(f"O Weblate em {url} não respondeu em {READY_TIMEOUT}s. Confira `docker compose logs weblate`.")
        return 1
    try:
        if action == "init":
            slug = ensure_project(api, project)
            ensure_components(api, slug)
            ensure_glossary(api, slug, project["translation_languages"], project["glossary"])
        elif action == "deploy-keys":
            return ensure_deploy_keys()
        elif action == "pull":
            repository_operation(api, project["slug"], "pull")
        else:
            repository_operation(api, project["slug"], "commit")
            repository_operation(api, project["slug"], "push")
    except subprocess.CalledProcessError as exc:
        print(f"Falha ao rodar {' '.join(exc.cmd[:4])}: {exc.stderr.strip()}")
        return 1
    except (ApiError, error.URLError, HTTPException, OSError) as exc:
        print(f"Falha ao falar com o Weblate em {url}: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

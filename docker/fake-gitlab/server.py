"""GitLab fake do E2E de sistema: responde, com JSON fixo, as rotas do GitLab que o Service chama.

Sem dependências (só a biblioteca padrão). O Service aponta para cá com GITLAB_BASE_URL=http://fake-gitlab:8929.
"""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

BASE = "http://fake-gitlab:8929"
TOKEN = "fake-gitlab-token"

USER = {
    "id": 9001,
    "username": "e2e-gitlab",
    "name": "E2E GitLab",
    "email": "e2e-gitlab@msgram.local",
    "avatar_url": None,
    "bio": "",
    "web_url": f"{BASE}/e2e-gitlab",
}
GROUP = {
    "id": 9100,
    "name": "e2e-grupo",
    "path": "e2e-grupo",
    "full_path": "e2e-grupo",
    "description": "Grupo do E2E",
    "avatar_url": None,
    "web_url": f"{BASE}/groups/e2e-grupo",
}
PROJECT = {
    "id": 9201,
    "name": "e2e-projeto",
    "path": "e2e-projeto",
    "path_with_namespace": "e2e-grupo/e2e-projeto",
    "description": "Projeto do E2E",
    "web_url": f"{BASE}/e2e-grupo/e2e-projeto",
    "permissions": {"project_access": {"access_level": 40}},
}

ROUTES = {
    "/api/v4/user": USER,
    "/api/v4/groups": [GROUP],
    f"/api/v4/groups/{GROUP['id']}": GROUP,
    f"/api/v4/groups/{GROUP['id']}/projects": [PROJECT],
    "/api/v4/projects": [PROJECT],
    f"/api/v4/projects/{PROJECT['id']}": PROJECT,
}

# uma página só: o Service segue X-Next-Page / X-Total-Pages
PAGE_HEADERS = {"X-Page": "1", "X-Total-Pages": "1", "X-Total": "1"}


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, body, headers=None):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlparse(self.path)
        path = url.path.rstrip("/")
        if path == "/health":
            return self.reply(200, {"status": "ok"})
        # o Service manda o token no header; o allauth, na query (?access_token=)
        if self.headers.get("Authorization") != f"Bearer {TOKEN}" and f"access_token={TOKEN}" not in url.query:
            return self.reply(401, {"message": "401 Unauthorized"})
        if path not in ROUTES:
            return self.reply(404, {"message": "404 Not Found"})
        body = ROUTES[path]
        return self.reply(200, body, PAGE_HEADERS if isinstance(body, list) else None)

    def do_HEAD(self):
        # o Service confere se a página web do projeto existe antes de gravar o repositório
        found = urlparse(self.path).path.rstrip("/") == urlparse(PROJECT["web_url"]).path
        self.send_response(200 if found else 404)
        self.end_headers()

    def do_POST(self):
        if urlparse(self.path).path != "/oauth/token":
            return self.reply(404, {"message": "404 Not Found"})
        length = int(self.headers.get("Content-Length") or 0)
        form = self.rfile.read(length).decode()
        # o /gitlab/validate/ do Service manda um code de mentira e espera 400 (credenciais válidas)
        if "code=dummy_verification_token" in form:
            return self.reply(400, {"error": "invalid_grant"})
        return self.reply(
            200,
            {
                "access_token": TOKEN,
                "token_type": "Bearer",
                "expires_in": 7200,
                "refresh_token": "fake-gitlab-refresh",
                "scope": "read_user openid profile email read_api",
                "created_at": 1700000000,
            },
        )


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8929), Handler).serve_forever()

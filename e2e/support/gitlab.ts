import { APIRequestContext, expect, Page } from '@playwright/test';
import { cookieValue, SESSION_COOKIES } from './seed';

/** O que o fake-gitlab (docker/fake-gitlab/server.py) devolve. */
export const FAKE_GITLAB = {
  username: 'e2e-gitlab',
  group: { id: 9100, name: 'e2e-grupo', description: 'Grupo do E2E' },
  project: { name: 'e2e-projeto', path: 'e2e-grupo/e2e-projeto' }
};

/**
 * Login com GitLab. O botão leva a /auth/oauth/gitlab, que valida o client id no Service, grava o cookie do state e
 * redireciona para https://gitlab.com/oauth/authorize (URL fixa no Front). Essa rota é chamada sem seguir o redirect
 * (o Playwright não intercepta o 2º salto, e o navegador iria ao gitlab.com de verdade); a tela de consentimento vira
 * a volta direta ao redirect_uri com um code. Daí em diante é tudo real: o Front manda o code ao /bff/session, e o
 * Service troca no fake-gitlab (/oauth/token) e busca o usuário (/api/v4/user).
 */
export async function loginWithGitlab(page: Page): Promise<string> {
  await page.goto('/auth/');
  await expect(page.getByRole('button', { name: 'LOGIN COM GITLAB' })).toBeVisible();

  const start = await page.request.get('/auth/oauth/gitlab/', { maxRedirects: 0 });
  expect(start.status(), await start.text()).toBe(307);
  const authorize = new URL(start.headers()['location']);
  expect(authorize.origin + authorize.pathname).toBe('https://gitlab.com/oauth/authorize');

  const back = new URL(authorize.searchParams.get('redirect_uri') ?? '/');
  back.searchParams.set('code', 'e2e-code');
  back.searchParams.set('state', authorize.searchParams.get('state') ?? '');
  const session = page.waitForResponse((r) => r.url().endsWith('/bff/session') && r.request().method() === 'POST');
  await page.goto(back.toString());
  expect((await session).status()).toBe(200);
  await expect(page).toHaveURL(/\/home\/?$/);
  const token = await cookieValue(page, SESSION_COOKIES.token);
  expect(token).toBeTruthy();
  return token as string;
}

/** A organização do grupo do GitLab (o Service busca o grupo no fake-gitlab) e um produto novo nela. */
export async function groupWithNewProduct(request: APIRequestContext, token: string, product: string) {
  const headers = { Authorization: `Token ${token}` };
  const org = await request.post('/api/v1/organizations/import-gitlab/', {
    headers,
    data: { gitlab_group_id: FAKE_GITLAB.group.id }
  });
  expect(org.status(), await org.text()).toBe(201);
  const { id: organizationId } = await org.json();
  const created = await request.post(`/api/v1/organizations/${organizationId}/products/`, {
    headers,
    data: { name: product }
  });
  expect(created.status(), await created.text()).toBe(201);
  return { organizationId: String(organizationId), productId: String((await created.json()).id) };
}

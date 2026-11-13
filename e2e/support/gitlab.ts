import { APIRequestContext, expect, Page } from '@playwright/test';

/** O que o fake-gitlab (docker/fake-gitlab/server.py) devolve. */
export const FAKE_GITLAB = {
  username: 'e2e-gitlab',
  group: { id: 9100, name: 'e2e-grupo', description: 'Grupo do E2E' },
  project: { name: 'e2e-projeto', path: 'e2e-grupo/e2e-projeto' }
};

/**
 * Login com GitLab. O Front manda o navegador para https://gitlab.com/oauth/authorize (URL fixa no código); só essa
 * tela de consentimento do GitLab é trocada por um redirect de volta com um code. Daí em diante é tudo real: o Front
 * manda o code ao Service, que troca no fake-gitlab (/oauth/token) e busca o usuário (/api/v4/user).
 */
export async function loginWithGitlab(page: Page): Promise<string> {
  await page.route('https://gitlab.com/oauth/authorize**', (route) => {
    const authorize = new URL(route.request().url());
    const back = new URL(authorize.searchParams.get('redirect_uri') ?? '/');
    back.searchParams.set('code', 'e2e-code');
    back.searchParams.set('state', authorize.searchParams.get('state') ?? '');
    return route.fulfill({ status: 302, headers: { location: back.toString() } });
  });

  await page.goto('/auth/');
  const login = page.waitForResponse((r) => r.url().endsWith('/api/v1/accounts/gitlab/login/'));
  await page.getByRole('button', { name: 'LOGIN COM GITLAB' }).click();
  expect((await login).status()).toBe(200);
  await expect(page).toHaveURL(/\/home\/?$/);
  return page.evaluate(() => JSON.parse(localStorage.getItem('token') ?? 'null'));
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

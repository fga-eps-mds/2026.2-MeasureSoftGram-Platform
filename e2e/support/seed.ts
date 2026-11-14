import { APIRequestContext, expect, Page } from '@playwright/test';

/** Os dados fixos do `python manage.py seed_e2e` do Service (src/organizations/management/commands/seed_e2e.py). */
export const SEED = {
  username: process.env.E2E_USERNAME ?? 'e2e',
  email: process.env.E2E_EMAIL ?? 'e2e@msgram.local',
  password: process.env.E2E_PASSWORD ?? 'e2e-senha',
  organization: 'E2E Org',
  product: 'E2E Produto',
  repository: 'e2e-repo',
  release: 'E2E Release 1'
};

/** Nome que não repete entre execuções contra a mesma stack. */
export const unique = (prefix: string) => `${prefix} ${Date.now().toString(36)}`;

/** Login por usuário e senha direto no Service (a tela de login do Front só tem GitHub e GitLab). */
export async function apiLogin(request: APIRequestContext): Promise<string> {
  const response = await request.post('/api/v1/accounts/login/', {
    data: { username: SEED.username, password: SEED.password }
  });
  expect(response.status(), await response.text()).toBe(200);
  return (await response.json()).key;
}

/** Os cookies da sessão do Front (src/shared/server/auth/cookies.ts); só o servidor do Next os lê. */
export const SESSION_COOKIES = { token: 'msgram_token', provider: 'msgram_provider', loginAt: 'msgram_login_at' };

/** Grava a sessão nos mesmos cookies que o login do Front grava. */
export async function useToken(page: Page, token: string): Promise<void> {
  const url = process.env.E2E_BASE_URL ?? 'http://localhost'; // o mesmo baseURL do playwright.config.ts
  await page.context().addCookies(
    [
      [SESSION_COOKIES.token, token],
      [SESSION_COOKIES.provider, 'credentials'],
      [SESSION_COOKIES.loginAt, Date.now().toString()]
    ].map(([name, value]) => ({ name, value, url }))
  );
}

/** Valor de um cookie da página, ou null sem ele. */
export async function cookieValue(page: Page, name: string): Promise<string | null> {
  return (await page.context().cookies()).find((cookie) => cookie.name === name)?.value || null;
}

/** Entra com o usuário do seed e espera a home. */
export async function login(page: Page): Promise<string> {
  const token = await apiLogin(page.request);
  await useToken(page, token);
  await page.goto('/');
  await expect(page).toHaveURL(/\/home\/?$/);
  return token;
}

/** O id de uma entidade do seed pela lista da API (os ids dependem do banco). */
export async function seedIds(request: APIRequestContext, token: string) {
  const headers = { Authorization: `Token ${token}` };
  const orgs = await (await request.get('/api/v1/organizations/', { headers })).json();
  const org = (orgs.results ?? orgs).find((o: { name: string }) => o.name === SEED.organization);
  const products = await (await request.get(`/api/v1/organizations/${org.id}/products/`, { headers })).json();
  const product = (products.results ?? products).find((p: { name: string }) => p.name === SEED.product);
  return { organizationId: String(org.id), productId: String(product.id) };
}

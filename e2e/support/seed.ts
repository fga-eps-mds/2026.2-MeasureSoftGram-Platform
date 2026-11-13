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

/** Guarda a sessão como o signInWithCredentials do Front: token, provider e o início da sessão. */
export async function useToken(page: Page, token: string): Promise<void> {
  await page.addInitScript((key) => {
    if (sessionStorage.getItem('e2e-sessao')) return; // só na primeira página: o logout tem de valer
    sessionStorage.setItem('e2e-sessao', '1');
    localStorage.setItem('token', JSON.stringify(key));
    localStorage.setItem('provider', JSON.stringify('credentials'));
    localStorage.setItem('login_timestamp', Date.now().toString());
  }, token);
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

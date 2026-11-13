import { expect, test } from '@playwright/test';
import { apiLogin, login, SEED } from '../support/seed';

test('@SIS-01 login com usuário e senha do seed e logout pelo menu do usuário', async ({ page }) => {
  const token = await login(page);
  await expect(page.getByText(`Bem vindo ao MeasureSoftGram ${SEED.username}!`)).toBeVisible();

  // o menu lateral já mostra os dados do seed
  await expect(page.getByRole('combobox').filter({ hasText: SEED.organization })).toBeVisible();

  await page.getByText(SEED.username, { exact: true }).click();
  const logout = page.waitForResponse((r) => r.url().endsWith('/api/v1/accounts/logout/'));
  await page.getByRole('menuitem', { name: /Finalizar Sessão|Log out/ }).click();
  expect((await logout).ok()).toBeTruthy();

  await expect(page.getByText('Volte logo para acompanhar seus produtos!')).toBeVisible();
  await expect.poll(() => page.evaluate(() => localStorage.getItem('token'))).toBeNull();

  // o Service invalidou o token
  const after = await page.request.get('/api/v1/accounts/', { headers: { Authorization: `Token ${token}` } });
  expect(after.status()).toBe(401);
});

test('@SIS-01 senha errada é recusada pelo Service', async ({ request }) => {
  const response = await request.post('/api/v1/accounts/login/', {
    data: { username: SEED.username, password: 'senha-errada' }
  });
  expect(response.status()).toBe(400);
  expect(await response.text()).toContain('Invalid username/email or password');
  // e a certa continua valendo
  expect(await apiLogin(request)).toBeTruthy();
});

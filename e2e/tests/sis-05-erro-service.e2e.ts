import { expect, test } from '@playwright/test';
import { login, seedIds } from '../support/seed';

test('@SIS-05 produto inexistente: o Service responde 404 e a tela mostra o erro com "Tentar novamente"', async ({
  page
}) => {
  const token = await login(page);
  const { organizationId } = await seedIds(page.request, token);
  const missing = 999999;

  const notFound = page.waitForResponse((r) => r.url().includes(`/products/${missing}/`) && r.status() === 404);
  await page.goto(`/products/${organizationId}-${missing}-Inexistente/`);
  await notFound;

  const alert = page.getByRole('alert').filter({ hasText: 'Não foi possível carregar os dados do gráfico de pulso.' });
  await expect(alert).toBeVisible();
  await expect(alert.getByRole('button', { name: /Tentar novamente/i })).toBeVisible();
});

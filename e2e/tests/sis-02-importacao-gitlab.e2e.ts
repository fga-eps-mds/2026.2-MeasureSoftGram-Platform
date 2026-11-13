import { expect, test } from '@playwright/test';
import { FAKE_GITLAB, groupWithNewProduct, loginWithGitlab } from '../support/gitlab';
import { unique } from '../support/seed';

test('@SIS-02 login com GitLab e importação de um projeto do grupo para um produto', async ({ page }) => {
  const token = await loginWithGitlab(page);
  const product = unique('Produto GitLab');
  const { organizationId, productId } = await groupWithNewProduct(page.request, token, product);
  await page.evaluate((id) => localStorage.setItem('selectedOrgId', JSON.stringify(id)), organizationId);

  await page.goto('/products/');
  await expect(page.getByRole('heading', { name: 'Importação de Projetos' })).toBeVisible();
  await expect(page.getByRole('combobox', { name: /^Grupos do GitLab/ })).toHaveText(
    `${FAKE_GITLAB.group.name} (${FAKE_GITLAB.group.description})`
  );
  const productSelect = page.getByRole('combobox', { name: /^Produtos do MeasureSoftGram/ });
  if ((await productSelect.textContent())?.trim() !== product) {
    await productSelect.click();
    await page.getByRole('option', { name: product }).click();
  }
  await expect(productSelect).toHaveText(product);

  // produto novo: abre em "A Importar", com o projeto que o Service buscou no fake-gitlab
  await page.getByRole('tab', { name: 'A Importar' }).click();
  const item = page.locator('ul.MuiList-root > li').filter({ hasText: FAKE_GITLAB.project.path });
  await expect(item).toBeVisible();

  const created = page.waitForResponse(
    (r) => r.request().method() === 'POST' && r.url().endsWith(`/products/${productId}/repositories/`)
  );
  await item.getByRole('button', { name: 'Importar' }).click();
  expect((await created).status()).toBe(201);
  await expect(page.getByText(`Projeto ${FAKE_GITLAB.project.name} importado com sucesso!`)).toBeVisible();

  await page.getByRole('tab', { name: 'Importados' }).click();
  await expect(page.locator('ul.MuiList-root > li').filter({ hasText: FAKE_GITLAB.project.path })).toBeVisible();

  // gravado no Service, como projeto do GitLab
  const repos = await page.request.get(`/api/v1/organizations/${organizationId}/products/${productId}/repositories/`, {
    headers: { Authorization: `Token ${token}` }
  });
  const [repo] = (await repos.json()).results;
  expect(repo).toMatchObject({ name: FAKE_GITLAB.project.name, platform: 'gitlab' });
});

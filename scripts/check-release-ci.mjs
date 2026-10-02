// Deployment accepts only the exact main commit whose complete CI run passed.
const { GITHUB_TOKEN: token, GITHUB_REPOSITORY: repository, GITHUB_SHA: sha,
  GITHUB_REF: ref, DOLPIN_RELEASE_SHA: expected } = process.env;
if (!token || !repository || ref !== 'refs/heads/main' || !/^[a-f0-9]{40}$/.test(expected ?? '') || expected !== sha) {
  throw new Error('Select main and supply its exact 40-character commit SHA.');
}
const endpoint = new URL(`https://api.github.com/repos/${repository}/actions/workflows/ci.yml/runs`);
endpoint.search = new URLSearchParams({ branch: 'main', head_sha: sha, status: 'success', per_page: '100' }).toString();
const response = await fetch(endpoint, {
  headers: { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' },
  signal: AbortSignal.timeout(15_000), redirect: 'error',
});
if (!response.ok) throw new Error(`CI evidence request failed (${response.status}).`);
const result = await response.json();
if (!result.workflow_runs?.some(run => run.head_sha === sha && run.head_branch === 'main' &&
  ['push', 'workflow_dispatch'].includes(run.event) && run.status === 'completed' && run.conclusion === 'success')) {
  throw new Error('This main commit has no successful complete CI run. Run CI before deployment.');
}
console.log(`CI evidence accepted for commit ${sha}.`);

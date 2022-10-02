# Lessons learned from setting up this Github Action/Workflow

1. Create three distinct jobs using the `needs:[dependent-job]` to  1. deploy infra, 2. build code, and 3. deploy code.
2. In the *build code* job, use `zip` to compress the deployment artifacts and use `actions/upload-artifact` as a step to upload it to staging area so it be downloaded during the *deploy code* job with `actions/download-artifact`.
3. GH does not support nested variables, e.g., `${$var:x:y}`.  Nested variables will result in the a 'bad substitution' error.
4. Define job `outputs` to pass variables between jobs.  **Important reminder**: job outputs are only available to downstream jobs that depend on that job.  Example:  If job1 has outputs, job3 must have `needs:[job3]` present.
5. To pass variables between steps within the same job, use `echo "::set-output name=<output name>::$<local variable>"`.  Also use `id` to provide the step with id to be used as a reference, e.g., `id: <step-id-name>`  Then to reference it in a subsequent step, use `${{steps.<step-id-name>.outputs.<output name>}}`
6. To diable a job, use `if: ${{ false }}`
7. Generated a hash of the target resource group's id since a resource group is always unique with a subscription.  Used a substring of this hash to provide a unique suffix that is appended to the function app name, which is passed as parameter to the bicep file.  This ensures the function app name always stays the same within the given resource group.  These changes ensure the workflow remains idempotent.

References:
1. https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions
2. https://docs.github.com/en/actions/using-jobs/defining-outputs-for-jobs
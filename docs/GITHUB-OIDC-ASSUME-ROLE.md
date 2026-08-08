# GitHub Actions → AWS via AssumeRole + OIDC (instructor reference)

Transcription of the instructor's guide **"Github Actions Assuming Role + OIDC"**, posted to Google
Classroom (topic *Projects* → *Practice Project*) after session 41 (02/08/2026). Subtitled
*"Best Practice Alternative for AWS Access Keys"*.

Kept verbatim in substance so this repo's setup can be checked against the graded reference. The
instructor's example uses the **pacman** practice project and his own account; our equivalents are
noted alongside.

---

## 1. Add the GitHub Actions Identity Provider in IAM

- **Provider URL:** `https://token.actions.githubusercontent.com`
- **Audience:** `sts.amazonaws.com`

## 2. Create an IAM Role — Trusted entity type: **Web identity**

### Permission policy (instructor's, for pacman)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EKSDescribeCluster",
      "Effect": "Allow",
      "Action": "eks:DescribeCluster",
      "Resource": "arn:aws:eks:us-west-2:416338226474:cluster/pacman-cluster"
    },
    {
      "Sid": "ECRPushToPacmanRepo",
      "Effect": "Allow",
      "Action": [
        "ecr:CompleteLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:InitiateLayerUpload",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:BatchGetImage"
      ],
      "Resource": "arn:aws:ecr:us-west-2:416338226474:repository/myapps/pacman"
    },
    {
      "Sid": "ECRGetAuthToken",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    }
  ]
}
```

> **Ours:** [`../iam/github-actions-permissions.json`](../iam/github-actions-permissions.json) — same
> three statements, scoped to `namegen-cluster` and the `namegen` ECR repo.

### Trust policy (instructor's)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::416338226474:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:omor13@OWNER_ID/pacman-project@REPOSITORY_ID:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

> ### ⚠️ This is the part that breaks — note the `sub` format
>
> ```
> repo:<owner>@<OWNER_ID>/<repo>@<REPOSITORY_ID>:ref:refs/heads/main
> ```
>
> The **numeric owner ID and repository ID** are appended with `@` after each name. GitHub introduced
> this on **15 July 2026**. **AWS's console-generated trust policy still emits the old format**
> (`repo:<owner>/<repo>:...` under `StringLike`), which fails with
> `Not authorized to perform sts:AssumeRoleWithWebIdentity` even though it looks correct. Note it is
> **`StringEquals`**, not `StringLike`, and that `aud` and `sub` sit in the *same* `StringEquals`
> block.
>
> This cost a full hour of live debugging in session 41.
>
> **Ours:** [`../iam/github-oidc-trust-policy.json`](../iam/github-oidc-trust-policy.json), filled in
> automatically by [`../scripts/02-setup-github-oidc.sh`](../scripts/02-setup-github-oidc.sh) which
> fetches both IDs from the GitHub API.

## 3. Look up the GitHub `OWNER_ID` and `REPOSITORY_ID`

```
https://api.github.com/repos/<owner>/<repo>
```

`.owner.id` → **OWNER_ID**, `.id` → **REPOSITORY_ID**.

```bash
# ours (private repo, so it needs a token)
curl -s https://api.github.com/repos/RazKimhi13/namegen-eks \
     -H "Authorization: token $(gh auth token)" \
  | python -c "import sys,json;d=json.load(sys.stdin);print(d['owner']['id'], d['id'])"
```

## 4. Create an EKS **access entry** for the GitHub role

With **`AmazonEKSClusterAdminPolicy`** — the role needs permissions *inside* Kubernetes, not just in
IAM. See [`EKS-ACCESS-ENTRIES.md`](EKS-ACCESS-ENTRIES.md). (Access entries accept a **user, a group,
or a role**; switching from key-based auth to OIDC means re-pointing the entry from the IAM *user* to
the *role*.)

## 5. Update the GitHub Actions workflow

Add, directly under the trigger:

```yaml
permissions:
  id-token: write     # REQUIRED for OIDC — nothing works without it
  contents: read
```

And replace the access-key step with:

```yaml
- name: Configure temporary AWS credentials
  uses: aws-actions/configure-aws-credentials@v6.2.3
  with:
    role-to-assume: arn:aws:iam::416338226474:role/Github_actions_role
    role-session-name: github-actions-${{ github.run_id }}
    aws-region: us-west-2
```

> **Ours:** [`../.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) — same shape, with
> the role ARN kept in the repo secret `AWS_ROLE_ARN` rather than hard-coded. We pin
> `configure-aws-credentials@v4`; the instructor landed on `v6.2.3` after trying several. The version
> was **not** the cause of the failure (he confirmed v4 works too) — the trust-policy format was.
> `role-session-name` includes `github.run_id` so each run opens a uniquely-named STS session.

---

## Why this instead of access keys

Access keys are **permanent** and **carry no identity** — whoever holds them gets in, with no
verification of who they are. AssumeRole works like a passport: AWS trusts an external issuer
(GitHub), verifies the caller, and **STS** issues **temporary** credentials tied to a role and a
session, scoped to one repo and one branch.

**Exam angle:** when asked how an application / code / third-party service should get access to an
AWS service, the answer is **AssumeRole / role-based access**, never "create access keys". The
distractors will offer key creation.

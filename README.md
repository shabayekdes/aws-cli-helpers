## AWS Helpers – User Guide

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 1) Prerequisites

- [ ] Install AWS CLI v2 (`aws --version`)
- [ ] Configure AWS SSO profiles in `~/.aws/config` (must include `sso_account_id` and `region`)
- [ ] Install `jq` for JSON parsing

Example AWS profile (in `~/.aws/config`):

```ini
[profile my-sso-profile]
sso_start_url = https://example.awsapps.com/start
sso_region = us-east-1
sso_account_id = 123456789012
sso_role_name = ReadOnly
region = us-east-1
output = json
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 2) Setup (Load the helpers into your shell)

- [ ] Decide how you want to load the helpers:
  - **One-time (current shell only):**
    - [ ] Run:

```bash
source /Users/mohamedshabaan/Workspace/Data/Devops/aws/helpers/main.sh
```

  - **Permanent (every new shell):**
    - [ ] Add to `~/.zshrc`, `~/.bashrc`(or `~/.bash_profile`:

Notes:
- `main.sh` exports `AWS_HELPERS_DIR` and loads all helper functions and aliases.
- An alias `sso_login` is created for convenience: `sso_login <profile>`.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 3) Commands Provided

- [ ] `aws_session`
  - [ ] Interactively select an AWS SSO profile (parses `~/.aws/config` for `sso_account_id` and `region`)
  - [ ] Performs SSO login if not already authenticated
  - [ ] Ensures the SSM session document `SSM-SessionManagerRunShell` exists (creates if missing using `templates/SessionManagerRunShell.json`)
  - [ ] Clears the terminal and displays account/profile/region in a styled table
  - [ ] Sets a helpful prompt showing `user@account:profile:region`

- [ ] `sso_login <profile>` (alias)
  - [ ] Shortcut for `aws sso login --profile <profile>`

- [ ] `ec2` helper with subcommands:
  - [ ] `ec2 ls` — list all EC2 instances (id, name, state)
  - [ ] `ec2 ls-running` — list only running EC2 instances
  - [ ] `ec2 session <instance-id>` — start an SSM shell session using `SSM-SessionManagerRunShell`
  - [ ] `ec2 port-forward <remote-port> <local-port> <instance-id>` — start SSM port forwarding

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 4) Typical Workflow

- [ ] Load the helpers (see Setup above)
- [ ] Run `aws_session`
  - [ ] Select your desired profile from the interactive list
  - [ ] If prompted, complete SSO login in your browser
  - [ ] Verify the printed table shows the expected Account, Profile, Region
- [ ] Use EC2 helpers as needed, for example:
  - [ ] `ec2 ls`
  - [ ] `ec2 ls-running`
  - [ ] `ec2 session i-0123456789abcdef0`
  - [ ] `ec2 port-forward 5432 15432 i-0123456789abcdef0`

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 5) Verification Steps (Success Criteria)

- [ ] Running `aws_session` shows a bordered table with:
  - [ ] Correct AWS Account (formatted `XXXX-XXXX-XXXX`)
  - [ ] Selected AWS Profile
  - [ ] Current Region
  - [ ] Identity ARN and User ID
- [ ] `ec2 ls` outputs instances data as JSON lines (via `jq -r`), without errors
- [ ] `ec2 session <instance-id>` starts an interactive SSM shell session
- [ ] `ec2 port-forward <remote-port> <local-port> <instance-id>` starts an SSM port forwarding session
- [ ] Your shell prompt updates to include `user@account:profile:region`

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 6) Troubleshooting

- [ ] `jq: command not found`
  - [ ] Install `jq` (macOS: `brew install jq`)

- [ ] `aws: command not found` or AWS CLI v1 detected
  - [ ] Install `awscli` (macOS: `brew install awscli`)

- [ ] No profiles listed in `aws_session`
  - [ ] Ensure your `~/.aws/config` profiles include both `sso_account_id` and `region`
  - [ ] Example provided in the Prerequisites section

- [ ] SSM session errors
  - [ ] Ensure the instance has SSM agent installed and proper IAM role
  - [ ] Ensure network/VPC endpoints allow SSM
  - [ ] Confirm `SSM-SessionManagerRunShell` exists (it is auto-created by `aws_session` if missing)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 7) Repository Structure

- [ ] `main.sh` — Entrypoint; exports `AWS_HELPERS_DIR`, loads sessions and EC2 helpers
- [ ] `session.sh` — Session orchestration: profile picker, SSO login, table display, SSM doc ensure
- [ ] `services/ec2.sh` — `ec2` command group: list instances, SSM session, port forwarding
- [ ] `templates/SessionManagerRunShell.json` — SSM document used for interactive shell sessions

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 8) Uninstall / Disable

- [ ] Remove or comment the `source /Users/mohamedshabaan/Workspace/Data/Devops/aws/helpers/main.sh` line from:
  - [ ] `~/.zshrc` (Zsh) or
  - [ ] `~/.bashrc` / `~/.bash_profile` (Bash)
- [ ] Restart your terminal (or re-source the rc file)



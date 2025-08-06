1. Using Workflow Dispatch
You can configure your workflow to allow manual triggering via the GitHub UI. To do this, you need to add the workflow_dispatch event to your workflow YAML file. Here’s how you can modify your existing workflow:

```yaml
name: Convert Documentation
on:
  push:
    branches: [ main ]
    paths:
      - 'docs/components/**/**/Eco.Core1_EN.fodt'  # for tests purpose one file only
  workflow_dispatch:  # Allow manual triggering of the workflow

```

With this configuration, you can manually trigger the workflow from the "Actions" tab in your GitHub repository.

2. Using Push Events
If you want the workflow to run automatically whenever certain conditions are met (like pushing to a specific branch or changing specific files), ensure that you have the correct on triggers defined in your workflow YAML. For instance, your existing configuration already listens to pushes to the main branch and changes to specific paths.

3. Using Repository Dispatch
You can trigger workflows from another workflow or from an external system using the repository_dispatch event. This requires you to send a POST request to the GitHub API. Here’s an example of how to set it up:

In Workflow YAML:


Add the following to your workflow to listen for a repository dispatch event:


```yaml


   on:
     repository_dispatch:
       types: [run-workflow]  # Custom event type
Triggering the Event:

```
trigger this event using a curl command or any HTTP client. Here’s an example using curl:


```bash


curl -X POST \
     -H "Accept: application/vnd.github.v3+json" \
     -H "Authorization: token YOUR_GITHUB_TOKEN" \
     https://api.github.com/repos/YOUR_USERNAME/YOUR_REPO/dispatches \
     -d '{"event_type": "run-workflow"}'
```

Replace YOUR_GITHUB_TOKEN, YOUR_USERNAME, and YOUR_REPO with your actual GitHub token and repository details.

4. Using Scheduled Events
If you want your workflow to run at specific intervals, you can set up a scheduled event using schedule. Here’s an example:

```yaml


on:
  schedule:
    - cron: '0 * * * *'  # Runs every hour

```

# GLab Command Line Tool

Functions for a user's GitLab repositories:

- Load projects information and navigate through all projects and change the visibility
- Load personal snippets information and navigate through all snippets and change the visibility

## Platforms tested

Ubuntu and macOS:

### Last updated 20.04.2024

    Linux 6.5.0-18-generic #18~22.04.1-Ubuntu SMP PREEMPT_DYNAMIC Wed Feb  7 11:40:03 UTC 2 x86_64 x86_64 x86_64 GNU/Linux
    Linux 6.5.0-1011-raspi #14-Ubuntu SMP PREEMPT_DYNAMIC Fri Feb  9 14:06:28 UTC 2024 aarch64 aarch64 aarch64 GNU/Linux
    Darwin 23.3.0 Darwin Kernel Version 23.3.0: Wed Dec 20 21:30:27 PST 2023; root:xnu-10002.81.5~7/RELEASE_ARM64_T8103 arm64

# Screenshot

<div align="center">

<img align="center" width="800" src="https://www.mascapp.com/taxadb/img/animationExampleE.webp.png">

</div>

# Setup

## `Zsh` - The Z shell

On macOS `zsh` is the standard shell. No installation required.

On Ubuntu 22.04 using `apt`

    apt install zsh

## `GLab` - A GitLab CLI

On macOS using `brew`:

    brew install glab

On Ubuntu 22.04 using `snap`:

    snap install --edge glab

## `jq` - A command-line JSON processor

On macOS using `brew`:

    brew install jq

On Ubuntu 22.04 using `apt`:

    apt install jq

# GitLab Login

Since glab version 1.29.0 (2023-05-04) there are two ways to log in to GitLab (`gitlab.com`) to get authorization for glab: via _Personal Authorization Token (PAT)_ or via _OAuth 2.0_.

For glab versions <1.29.0 only PAT is possible.

For both methods the following command guides you through the login process:

    glab auth login

Choose PAT ( = "Token") or OAuth 2.0 ( = "Web").

After successful login, run the script:

    ✓ Logged in as <user name>

Glab remembers the login, so this a one-time setup step.

# Run

    git clone https://gitlab.com/ms152718212/glab-cl.git
    cd glab-cl/src
    ./run.sh <userid>

## Commands

In the **Main view**:

Key | Command | GitLab Request | Request Type
--- | --- | --- | ---
`<UP>` `<DOWN>`| **Select** an item. | no | -
`<RIGHT>` | **Open** the **selected item view**. | yes, when there is no cached data | read
`number` |  **Open** the **item view <NR>**; first fetch all data | yes, when there is no cached data | read
`q` `<CTRL+C>` | **Quit** | no | -
`r`|  **Reset** the **view**, adjust page size to the window size. | no | -

In the **Projects** and **Personal Snippets** view:

Key | Command | GitLab Request | Request Type
--- | --- | --- | ---
`<UP>` `<DOWN>`| **Select** an item. | no | -
`<LEFT>` `<RIGHT>`| **Go to** the **previous** or **next page**. | no | -
`s`| **Switch**  ("toggle") the **visibility**, mark for the next update. | no | -
`u` |  **Reloads** the view with data from the cache. **Updates** locally changed data on GitLab. | yes | write, read
`U` |  **Delete** cached data. **Updates** all data. **Reloads** the view. | yes | write, read
`q` `<LEFT>` | **Return to Main view**. | no | -
`<CTRL+C>` | **Quit** | no | -
`c`|  **Clear cache and reset** the view, adjust page size according to the window size. | yes | read

## Clean up the cache

Requested data will be processed and stored locally [./src/data/tmp](./src/data/tmp) and used from there as a cache:

    src/data/tmp
    ├── 1689139347_cache
    │   ├── current_snippet_data_4306763.txt
    │   ├── current_snippet_data_4306763_26_1.txt
    ...
    │   └── current_snippet_data_4306763_6_2.txt
    ├── 1689143106_cache
    │   ├── current_project_data_4306763.txt
    │   └── current_project_data_4306763_26_1.txt
    ...
    ├── current_project_data_4306763.txt
    ├── current_project_data_4306763_10_1.txt
    ├── current_project_data_4306763_10_2.txt
    ...
    ├── current_snippet_data_4306763.txt
    ├── current_snippet_data_4306763_13_1.txt
    ├── current_snippet_data_4306763_22_1.txt
    └── current_snippet_data_4306763_26_1.txt

To avoid unintentionally deleting or overwriting data, there is no command in the script that deletes or overwrites files or folders. Therefore, it is good to manually delete all temporary folders with the pattern `<numbers>_cache` in [./src/data/tmp](./src/data/tmp) from time to time if. It is also safe to delete the entire contents of the folder [./src/data/tmp](./src/data/tmp), then the cache will be rebuilt the next time the scripts starts or with the command `u`.

# References

Zsh curses module -  https://zsh.sourceforge.io/Doc/Release/Zsh-Modules.html#The-zsh_002fcurses-Module

GLab - A GitLab CLI - https://docs.gitlab.com/ee/integration/glab/

jq - A command-line JSON processor - https://stedolan.github.io/jq/

A Curses Wiki - https://en.wikipedia.org/wiki/Curses_(programming_library)

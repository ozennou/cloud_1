# Cloud-1 — Concepts to Know Before Evaluation

This project chains three tools to deploy a WordPress stack to the cloud:

```
Terraform  ──►  Ansible  ──►  Docker Compose (Inception)
(provision      (configure      (run the app: nginx +
 an Azure VM)    the VM)         wordpress + mariadb + redis)
```

The repo has three matching folders:

| Folder       | Tool           | Job                                             |
|--------------|----------------|-------------------------------------------------|
| `infra/`     | Terraform      | Create the Azure VM + network + firewall        |
| `config/`    | Ansible        | Install Docker, copy the app, render secrets, run it |
| `inception/` | Docker Compose | The actual WordPress site in containers         |

The evaluator will likely ask you to **explain each layer, why it exists, and how they hand off to each other.** Below is what you need to be able to defend.

---

## 1. Infrastructure as Code (IaC) — the big idea

**IaC** means your servers are defined in text files, not clicked together by hand in a web console. Benefits to be able to state:

- **Reproducible** — run the same code, get the same infrastructure.
- **Version-controlled** — infra lives in git; changes are reviewable.
- **Declarative** — you describe the *desired end state*, the tool figures out the steps.

This project uses two IaC tools with different roles:
- **Terraform = provisioning** (create the machine and network).
- **Ansible = configuration management** (set up software *inside* the machine).

Know the difference — it's a classic evaluation question.

---

## 2. Terraform (`infra/`)

### What it does
Talks to the **Azure** API and creates real cloud resources. Provider is `hashicorp/azurerm` pinned to `=4.72.0` (`provider.tf`).

### Resources created (walk through these files)
- `main.tf` — a **Resource Group** (`rg-terraform`), the logical container for everything in Azure.
- `network.tf`:
  - **Virtual Network** (`10.0.0.0/16`) + **Subnet** (`10.0.1.0/24`) — the private network.
  - **Public IP** (Static) — so the VM is reachable from the internet.
  - **Network Security Group (NSG)** — the cloud firewall. Opens only **22 (SSH), 80 (HTTP), 443 (HTTPS)**.
- `vm.tf`:
  - **Linux VM** — Ubuntu 22.04 LTS, size `Standard_D2s_v3`.
  - **Network Interface (NIC)** — connects the VM to the subnet + public IP.
  - **NIC ↔ NSG association** — attaches the firewall to the NIC.
  - SSH-key auth only: `disable_password_authentication = true`, public key read from `~/.ssh/id_rsa.pub`.
- `variable.tf` — inputs (`location`, `vm_size`, `admin_username`) with defaults.
- `output.tf` — prints the VM's **public IP** after apply (this is the value you paste into Ansible's inventory).

### Core Terraform concepts to know
- **Provider** — plugin that lets Terraform talk to a platform (here Azure).
- **Resource** — one piece of infrastructure (`resource "type" "name" { ... }`).
- **State file** (`terraform.tfstate`) — Terraform's record of what it created, mapping your code to real Azure resources. **Gitignored** (it holds secrets). Losing it means Terraform loses track of your infra.
- **`plan` vs `apply`** — `plan` previews changes, `apply` executes them. `destroy` tears everything down.
- **Dependency graph** — Terraform auto-orders creation by references (e.g. the NIC references the subnet, so the subnet is built first). No manual ordering.
- **Idempotency** — re-running `apply` changes nothing if the config already matches reality.
- **Authentication** — done via **Service Principal** env vars in `secrets.sh` (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`). A Service Principal is a non-human "app identity" Azure uses to grant Terraform permission.

---

## 3. Ansible (`config/`)

### What it does
Once the VM exists, Ansible connects **over SSH** and configures it. It's **agentless** (nothing to pre-install on the target — just SSH + Python).

### Key files
- `inventory.ini` — the list of target hosts. Here: one host, `prd_eus_server_01`, at the Terraform-produced public IP, with SSH user + key. **You paste the Terraform output IP here.**
- `playbook.yml` — the ordered list of tasks (the recipe).
- `vars.yml` — non-secret variables (domain name, site title).
- `secrets.yml` — **Ansible Vault**-encrypted secrets (DB passwords, WP admin creds, Redis password).
- `templates/env.j2` — a **Jinja2** template that becomes the `.env` file on the VM.

### What the playbook does (be able to narrate it)
1. Check if Docker is installed; if not, install via the get.docker.com script.
2. Copy the entire `inception/` folder to the VM.
3. Install `make`.
4. **Render `env.j2` → `.env`** on the VM, filling in variables from `vars.yml` + `secrets.yml`.
5. Run `make up` to build and start the containers.

### Core Ansible concepts to know
- **Playbook / Play / Task / Module** — a playbook contains plays; each play runs tasks; each task calls a module (`copy`, `apt`, `template`, `shell`…).
- **Inventory** — who to configure.
- **Idempotency** — Ansible modules aim to only change things that need changing (note: the raw `shell`/`command` tasks here are *not* naturally idempotent, which is why `docker_check` + `when:` guards are used).
- **`become: true`** — privilege escalation (run as root / sudo).
- **Templating (Jinja2)** — `{{ VAR }}` placeholders filled at runtime. This is how secrets get onto the VM without hardcoding them in the app.
- **Ansible Vault** — encrypts `secrets.yml` at rest so credentials can live in git safely. You unlock it at run time with a vault password. **Know how to explain vault** — it's the answer to "how do you handle secrets?"

---

## 4. Inception — the Docker stack (`inception/`)

This is the 42 *Inception* project reused as the payload. WordPress split into **one service per container**, orchestrated by Docker Compose.

### Services (`srcs/docker-compose.yml`)
| Container    | Role                          | Notes |
|--------------|-------------------------------|-------|
| **nginx**    | Web server / reverse proxy, TLS termination | Only container with a published port (**443**). Self-signed cert generated at startup. Passes `.php` to WordPress via FastCGI. |
| **wordpress**| PHP-FPM app (no web server)   | WP-CLI installs & configures WordPress on first run, then `exec php-fpm81 -F`. |
| **mariadb**  | Database                      | Creates DB + user from env vars via `--bootstrap`. |
| **redis-cache** (bonus) | Object cache for WP | Speeds up WordPress by caching DB queries. |

### Core Docker concepts to know
- **Image vs Container** — image is the built blueprint; container is a running instance. Each service builds its own image from a `Dockerfile` (all based on `alpine:3.18`).
- **Dockerfile** — build recipe. Note `ENTRYPOINT` runs the service **in the foreground** (`-F`, `daemon off;`, `--daemonize no`) — a container dies if PID 1 exits, so the main process must not fork into the background.
- **Docker Compose** — defines and runs a multi-container app from one YAML file, with a shared network and dependency ordering (`depends_on`).
- **Bridge network** (`services_net`) — private network so containers reach each other by **service name** (e.g. nginx proxies to `wordpress:9000`, WP connects to `mariadb`). Only nginx is exposed externally.
- **Volumes** — persist data outside the container lifecycle. Here **bind mounts** to `/home/mozennou/data/{wp,mariadb}` on the host, so DB + site survive container restarts/rebuilds.
- **Environment variables** — all config/secrets injected from the `.env` (which Ansible rendered). No secrets baked into images.
- **Healthchecks** — each service defines one so Docker knows if it's actually up (e.g. mariadb: `nc -z 127.0.0.1 3306`; nginx: `nginx -t` + probe 443).
- **Restart policy** — `restart: unless-stopped` keeps services alive across reboots/crashes.
- **Startup ordering** — `depends_on` starts things in order, but doesn't wait for *readiness*. The WordPress `script.sh` therefore **polls** MariaDB and Redis in a loop before proceeding — an important detail to point out (`depends_on` ≠ "ready").

---

## 5. How the layers hand off (the end-to-end flow)

1. `source secrets.sh` → Azure credentials in your shell.
2. `terraform apply` in `infra/` → VM + network created; **public IP** printed.
3. Paste that IP into `config/inventory.ini`.
4. `ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass` → VM gets Docker, the app, a rendered `.env`, and `make up` runs.
5. Docker Compose builds 4 images and starts the stack.
6. Browse to `https://<public-ip>` → WordPress over HTTPS.

---

## 6. Security / secrets model (expect questions here)

- **SSH key auth only** — passwords disabled on the VM.
- **NSG firewall** — only 22/80/443 open.
- **Ansible Vault** — app secrets encrypted at rest in `secrets.yml`.
- **`.env` on the VM** — rendered with mode `0600`, gitignored.
- **`.gitignore`** excludes `secrets.sh`, `.env`, `*.tfstate`, `*.tfvars`.
- **Self-signed TLS cert** — generated in nginx at container start (why the browser shows a warning; that's expected for this project).

⚠️ **Before evaluation, double-check `secrets.sh`:** it currently contains **live Azure Service Principal credentials** in plaintext on disk. It *is* gitignored, but confirm it was never committed (`git log --all -- secrets.sh`) and consider **rotating that client secret** in Azure if there's any doubt it leaked.

---

## 7. Likely evaluation questions — quick answers

- **Terraform vs Ansible?** Terraform provisions infrastructure (the machine); Ansible configures what runs inside it. Provisioning vs configuration management.
- **Why is Terraform state important?** It's how Terraform maps your code to real cloud resources; it also stores sensitive data, so it's gitignored.
- **What makes Ansible agentless?** It works over plain SSH + Python; nothing to install on the target first.
- **How are secrets handled?** Ansible Vault encrypts them; they're templated into a `0600` `.env` at deploy time; nothing sensitive is committed or baked into images.
- **Why one process per container?** Isolation, independent scaling/restart, single responsibility — the core microservice idea Inception teaches.
- **Why does WordPress poll for MariaDB?** `depends_on` only controls start order, not readiness, so the app waits for the DB to actually accept connections.
- **Why is nginx the only exposed container?** It's the single entry point (reverse proxy + TLS); everything else stays on the private bridge network.
- **Idempotency?** Re-running `terraform apply` or the playbook converges to the same state without duplicating work.

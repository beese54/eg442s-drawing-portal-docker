# Schematic Drawing Portal — Containerised Deployment on AWS (EG442S Lab Assignment Part 2)

A web application for drawing water-pipe schematics and running rule-based compliance
checks on them, packaged with **Docker**, published to **Docker Hub**, and deployed on
**Amazon EC2** (AWS Academy Learner Lab).

| Deliverable | Where |
|---|---|
| Application source code | `backend/` (Python FastAPI) and `frontend/` (React + TypeScript) |
| Dockerfile | [`Dockerfile`](Dockerfile) |
| Docker Compose file | [`docker-compose.yml`](docker-compose.yml) |
| Docker image | https://hub.docker.com/r/dockerflocker456/drawing-portal |
| AWS deployment | Deployed and verified on 2 Nov 2026 at `http://54.234.52.243` (EC2 t3.micro, us-east-1). The Learner Lab IP changes per session; see slides 8–11 for evidence |
| Architecture diagram + commands | `presentation/EG442S_DrawingPortal_Docker.pptx` |

---

## 1. The application (Task 1)

* **Purpose:** draw a plumbing schematic on an elevation canvas (drag-and-drop from 70 symbols),
  then press **Evaluate** to run 8 deterministic compliance checks (backflow prevention, mode of
  supply, water efficiency, tank/pump rules, and others). Results can be exported as Word, PDF or JSON.
* **Frontend:** React 18 + TypeScript + Konva (canvas), built with Vite into static files.
* **Backend:** Python 3.12 + FastAPI, served by Uvicorn. It serves the REST API (`/api/...`)
  **and** the built frontend, so the browser talks to one origin on one port.
* **No database and no volume:** a drawing lives only in the browser. Nothing is saved on the
  server, so the container is stateless. Closing the session clears the drawing.

```
Browser ──HTTP──▶ Container (port 8000)
                    └─ Uvicorn / FastAPI
                         ├─ /            → React app (static files built in stage 1)
                         ├─ /api/symbols → symbol library (SVG files baked into the image)
                         ├─ /api/evaluate→ compliance checks (pure Python)
                         └─ /api/health  → health check used by Docker HEALTHCHECK
```

## 2. Containerise with Docker (Task 2)

The [`Dockerfile`](Dockerfile) is a **multi-stage build**:

| Stage | Base image | What it does |
|---|---|---|
| 1 `frontend-build` | `node:24-alpine` | `npm ci` then `npm run build`, which produces `dist/` (HTML/JS/CSS) |
| 2 runtime | `python:3.12-alpine` | `pip install` the backend, copy the code, symbols and **only** `dist/` from stage 1 |

Node.js and `node_modules` never reach the final image, which keeps it about 200 MB.
The container runs as a **non-root user**, `EXPOSE`s port 8000, and has a `HEALTHCHECK`
that calls `/api/health`.

```powershell
# Build the image
docker build -t drawing-portal:1.0 .

# List images
docker images drawing-portal

# Run a container: host port 8080 -> container port 8000
docker run -d --name drawing-portal -p 8080:8000 drawing-portal:1.0

# Verify: browse to http://localhost:8080, or
curl http://localhost:8080/api/health        # {"status":"ok","version":"1.0",...}

# Basic container management
docker ps                                     # running containers (STATUS shows "healthy")
docker logs drawing-portal                    # application logs (JSON lines)
docker exec -it drawing-portal sh             # shell inside the container (try: whoami -> app)
docker stop drawing-portal                    # stop
docker start drawing-portal                   # start again
docker rm -f drawing-portal                   # remove
```

## 3. Docker Compose (Task 3)

This is a single-container app, so [`docker-compose.yml`](docker-compose.yml) defines one service, `web`, with:
the build context, the Docker Hub image name, the **port** mapping `8080:8000`, a user-defined **bridge
network** `portal-net`, **environment variables** (`APP_VERSION`, `MAX_IMAGE_BYTES`) and
`restart: unless-stopped`. There is no volume because the app is stateless.

```powershell
docker compose up -d --build     # build + start
docker compose ps                # status
curl http://localhost:8080/api/health   # version shows "1.0-compose", which proves the env var reached the container
docker compose logs -f           # follow logs (Ctrl+C to exit)
docker compose down              # stop + remove container and network
```

## 4. Publish to Docker Hub (Task 4)

```powershell
docker login                                                   # Docker ID: dockerflocker456
docker tag drawing-portal:1.0 dockerflocker456/drawing-portal:1.0
docker tag drawing-portal:1.0 dockerflocker456/drawing-portal:latest
docker push dockerflocker456/drawing-portal:1.0
docker push dockerflocker456/drawing-portal:latest

# Prove the published image can be pulled and run
docker rmi dockerflocker456/drawing-portal:1.0
docker pull dockerflocker456/drawing-portal:1.0
docker run -d --name dp-from-hub -p 8081:8000 dockerflocker456/drawing-portal:1.0
```

Image page: https://hub.docker.com/r/dockerflocker456/drawing-portal

## 5. Deploy on AWS EC2 (Task 5) — following Lab 7b

**5.1 Launch the instance** (AWS Academy, then Learner Lab, then Start Lab, then AWS console, then EC2, then Launch instance)

| Setting | Value |
|---|---|
| Name | `yourname_drawingportal` |
| AMI | Amazon Linux 2023 (x86_64) |
| Instance type | `t3.micro` (2 vCPU, 1 GiB: enough for this app) |
| Key pair | `yourname_ec2` (.pem, saved in `C:\Users\<you>\.ssh`) |
| Network | default VPC, auto-assign public IP **enabled** |
| Security group | `yourname_ec2_group`: **SSH 22** (source: My IP) + **HTTP 80** (Anywhere IPv4 and IPv6) |
| Storage | 8 GiB gp3 (default) |

**5.2 Connect and install Docker**

```bash
ssh -i "yourname_ec2.pem" ec2-user@<Public-IPv4-DNS>

sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo systemctl enable docker      # start Docker automatically when the instance restarts
sudo docker --version
```

**5.3 Pull from Docker Hub and run**

```bash
# The image is public, so no docker login is needed to pull it
sudo docker pull dockerflocker456/drawing-portal:1.0
sudo docker run -d --name drawing-portal -p 80:8000 --restart unless-stopped \
     dockerflocker456/drawing-portal:1.0

sudo docker ps                         # wait for STATUS "(healthy)"
curl http://localhost/api/health       # test from inside the instance
```

**5.4 Open in a browser:** `http://<Public-IPv4-address>` (use **http**, not https).
If it times out, check the security group has the HTTP 80 inbound rule (Lab 7b step 3.4.10).

**5.5 Update / redeploy** (after pushing a new tag, e.g. `1.1`)

```bash
sudo docker pull dockerflocker456/drawing-portal:1.1
sudo docker rm -f drawing-portal
sudo docker run -d --name drawing-portal -p 80:8000 --restart unless-stopped dockerflocker456/drawing-portal:1.1
```

**5.6 Cost and clean-up:** the Learner Lab stops EC2 when the session ends. When the
instance starts again Docker and the container restart automatically
(`systemctl enable docker` + `--restart unless-stopped`), but the **public IP changes**, so check it
again in the console. After the assessment, **terminate** the instance and delete the security group.

### Optional: Amazon ECR as well (the brief says "both is encouraged")

```bash
# On your PC, using the AWS CLI credentials from Learner Lab -> AWS Details -> AWS CLI "Show"
aws ecr create-repository --repository-name drawing-portal --region us-east-1
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker tag drawing-portal:1.0 <account-id>.dkr.ecr.us-east-1.amazonaws.com/drawing-portal:1.0
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/drawing-portal:1.0
```
(Pulling from ECR on EC2 needs the instance profile `LabInstanceProfile` attached at launch.)

## 6. Architecture

```
 Developer PC (Windows + Docker Desktop)
   │ docker build  (multi-stage: node:24-alpine ─▶ python:3.12-alpine)
   │ docker push
   ▼
 Docker Hub  dockerflocker456/drawing-portal:1.0
   │ docker pull
   ▼
 AWS us-east-1 ── Default VPC ── Public subnet
   └─ Security group: inbound TCP 80 (0.0.0.0/0, ::/0), TCP 22 (my IP)
       └─ EC2 t3.micro · Amazon Linux 2023 · Docker Engine
            └─ container "drawing-portal"   host :80 ─▶ container :8000
                  Uvicorn + FastAPI (API + React static files)
   ▲
   │ http://<public-IP>
 User's browser
```

## 7. Challenges and how they were resolved

| Challenge | Resolution |
|---|---|
| The original project was a large work repo (CI, tests, internal docs, security audits) | Copied only what the image needs: `backend/app`, `backend/symbols`, `frontend` source and config. 181 files, 1.5 MB |
| The original app showed official government branding | Removed the banner, logo and footer links, so a public IP never looks like an official site |
| Frontend (Node) and backend (Python) need different toolchains | Multi-stage build: Node builds the frontend, and only the static output is copied into the Python image |
| Browser on port 80, app on port 8000 | Port mapping `-p 80:8000` on EC2 (`8080:8000` locally, to avoid clashing with anything on port 80) |
| Swagger `/docs` page was blank | The app's strict Content-Security-Policy blocks CDN scripts. Kept the security header and used `/api/health` for checks instead |
| Learner Lab stops EC2 after each session | `systemctl enable docker` + `--restart unless-stopped` bring the app back automatically. Re-check the new public IP |
| Image must match the instance CPU | The image was built on an x86 PC, so the instance uses an x86 AMI on t3.micro (an Arm t4g instance would not run it) |
| Screenshots going into a public repo | Cropped out the AWS account ID and Learner Lab username, and masked my home IP in the SSH rule |

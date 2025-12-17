# Hello World on EKS (Flask + PostgreSQL) — CI/CD Demo

This repository demonstrates a simple end-to-end deployment of a web application to **AWS EKS** using **GitHub Actions**, **Amazon ECR**, and a **Helm chart**.

The application is a small **Flask** service that:
- shows a simple UI page at `/`
- allows users to submit a message
- stores messages in a **PostgreSQL database**
- retrieves and displays stored messages from the database

---

## What’s in this repo

- `app/`  
  Flask application source code + Dockerfile.
- `hello-world-helm/`  
  Helm chart that deploys the app to Kubernetes (Deployment, Service, Secret, etc.).
- `.github/workflows/app-deploy.yml`  
  CI/CD pipeline: build image → package chart → validate → deploy.

---

## Prerequisites (one-time)

### AWS / Kubernetes
You need:
- An **EKS cluster** running (and reachable from the GitHub runner).
- An **ECR repository** (e.g. `hello-world-app`).
- A **self-hosted GitHub runner** with network access to the EKS API endpoint.

The runner should have these tools installed:
- `aws` CLI
- `kubectl`
- `helm`
- `docker` (with buildx support)

### GitHub secrets
Create these secrets in your GitHub repo settings:

- `AWS_ROLE_ARN`  
  IAM Role assumed by the workflow to access AWS.
- `DATABASE_URL`  
  PostgreSQL connection string used by the application, for example:
  `postgresql+psycopg2://USER:PASSWORD@HOST:5432/DBNAME`

> Important: the database **must exist** in Postgres (the app creates tables, but not the database itself).

---

## Setup instructions

### 1) Configure your database
Ensure the database referenced in `DATABASE_URL` already exists.

Example (if you can connect to the RDS instance):
```bash
psql -h <host> -U <user> -d postgres
CREATE DATABASE <dbname>;

# Final Project brief (verbatim from Classroom)

> Source: Classroom assignment "Final Project" (course 819639863400, coursework id 870874880596),
> Google Doc `1ffsgkzn6j1jDUQypl1M24nf6rg8OOo6m-KqCVc4WsI0` ("Final DevOps Project").
> **Due 2026-08-20 20:59 · 100 points.**

---

## EKS with CI/CD Pipeline - Final Project

**[Random Name Generator and Saver App]**

**Introduction:**

In your organization, the Dev Team develops **Random Name Generator and Saver App.**

The Node.js application publishes a web page that allows users to retrieve a name at random, then
store that random name in the database to which the application is bound. Also, the Node.js
application web page displays a list of names stored in the database.

The Node.js application has a server-side API that stores and retrieves data stored in the MongoDB
database. This application also publishes a web page that is bound to the server-side API. Users
interact with the page, and the page, in turn, interacts with the server-side API.

As a DevOps engineer, you received the application source code and were asked to implement and deploy
it using Amazon Elastic Kubernetes Service (EKS), AWS Native Services and other CI/CD tools.

**Application Components:**

**Source Code:** https://github.com/redhat-developer-demos/namegen

**Requirements:**
- Deploy and provision the infrastructure using Terraform or eksctl (use eks auto mode cluster)
- Build a CI/CD Workflow for EKS Workloads that automatically builds and deploys using **Github Actions**
- Expose your application using **load balancer (NLB)**
- Deploy a DB topology with a **StatefulSet** and **Persistent Volumes (PVs)**

**Tips:**
- Use **mongodb:3.6** version
- Use the following ENV variable in the app deployment:
  **MONGODB_URL=mongodb://genuser:password@mongodb/namegen**

**Submission:** a github repo containing:
- the Source Code in the root and Dockerfile
- A Diagram describing the architecture and the CI/CD pipeline (use draw.io)
- A README.md file with a detailed description of the project
- A folder with your Terraform modules / eksctl yaml
- A folder with your Kubernetes manifest files (YAML files)
- A folder with screenshots of your running application

**References:** Terraform docs · EKS getting-started · GitHub README format · GitHub Actions workflow syntax

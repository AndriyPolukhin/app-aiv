## Getting Started

### Prerequisites

For a local development environment, follow the instructions below

## System Requirements

-   [git](git) v2.13 or greater
-   [NodeJS](node) `>=16`
-   [npm](npm) v8.16.0 or greater

All of these must be available in your `PATH`. To verify things are set up properly, you can run this:

```bash
git --version
node --version
npm --version
```

### Installation

1. Clone the repository

```bash
git clone git remote add origin git@github.com:AndriyPolukhin/app-aiv.git
cd app-aiv
```

2. Docker 🐳 you can setup the project with the following command:

```shell
docker-compose up --build
```

3. Install dependencies in folders

```bash
cd frontend
npm install


cd backend
npm install
npm run dev
```

4. In order to start the services and populate the database

```bash
frontend/
npm run start

backend/
npm run dev

database:
npm run setup
```

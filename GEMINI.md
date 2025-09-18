# Project Overview

This project is a Dockerized deployment of Nextcloud, a suite of client-server software for creating and using file hosting services. It uses Docker Compose to orchestrate the Nextcloud application, a PostgreSQL database, and an optional Redis cache.

The project consists of three main services:

*   **`nextcloud-app`**: The main Nextcloud application.
*   **`nextcloud-db`**: The PostgreSQL database used by Nextcloud.
*   **`redis`**: (Optional) Redis cache for performance optimization.

The project is configured to store data in the following directories:

*   `./data/nextcloud-config`: Stores the Nextcloud configuration.
*   `./data/nextcloud-data`: Stores the user data.
*   `./data/postgres-data`: Stores the PostgreSQL database.

## Building and Running

To build and run the project, you can use the following Docker Compose commands:

*   **`docker compose  up -d`**: To start the services in detached mode.
*   **`docker compose  down`**: To stop the services.
*   **`docker compose  logs -f`**: To view the logs.

**Note:** Before running the project, you need to replace the placeholder passwords in the `docker compose .yml` or `.env` file with strong passwords.

## Development Conventions

This project is a deployment of pre-built Docker images, so there are no specific development conventions. However, it is important to keep the `docker compose .yml` and `.env` files under version control to track changes to the deployment configuration.
# Plan to Run Chapter 8: Project Pastra

This plan covers the steps to get the Chapter 8 application running, either on your local machine using Docker or deployed to Google Cloud Run.

**Option 1: Local Development (using Docker)**

This option is suitable for testing and development on your local machine.

1.  **Prerequisites:**
    *   Ensure you have Docker installed on your computer.
    *   Have your Gemini API key ready.
    *   The Chapter 8 code is available in the `/Users/ofekduani/Desktop/project pastra/gemini-multimodal-live-dev-guide/part_2_dev_api/chapter_08/` directory.

2.  **Steps:**
    *   Open your terminal.
    *   Navigate to the Chapter 8 directory:
        ```bash
        cd /Users/ofekduani/Desktop/project pastra/gemini-multimodal-live-dev-guide/part_2_dev_api/chapter_08/
        ```
    *   Build the Docker image. This command reads the `Dockerfile` and creates a container image named `project-pastra`.
        ```bash
        docker build -t project-pastra .
        ```
    *   Run the Docker container. This command starts a container from the `project-pastra` image, maps port 8080 on your local machine to port 8080 inside the container, and passes your Gemini API key as an environment variable named `GEMINI_API_KEY`.
        ```bash
        docker run -p 8080:8080 -e GEMINI_API_KEY='YOUR_GEMINI_API_KEY' project-pastra
        ```
        **Note:** Replace `'YOUR_GEMINI_API_KEY'` with your actual API key from Chapter 7.
    *   Access the application: Open your web browser and go to `http://localhost:8080`.

**Option 2: Deploying to Google Cloud Run**

This option deploys the application to a managed, scalable environment on Google Cloud.

1.  **Prerequisites:**
    *   A Google Cloud Platform (GCP) account.
    *   The `gcloud` command-line tool installed and configured to use your GCP account.
    *   Ensure the Cloud Build and Cloud Run APIs are enabled in your GCP project (`amitai-454317`).
    *   Have your Gemini API key ready.
    *   The Chapter 8 code is available in the `/Users/ofekduani/Desktop/project pastra/gemini-multimodal-live-dev-guide/part_2_dev_api/chapter_08/` directory.

2.  **Steps:**
    *   Open your terminal.
    *   Navigate to the Chapter 8 directory:
        ```bash
        cd /Users/ofekduani/Desktop/project pastra/gemini-multimodal-live-dev-guide/part_2_dev_api/chapter_08/
        ```
    *   Submit the build to Cloud Build. This command builds the Docker image in the cloud and stores it in your project's Container Registry.
        ```bash
        gcloud builds submit --tag gcr.io/amitai-454317/project-pastra-dev-api
        ```
        **Note:** Your project ID `amitai-454317` is included in the image tag.
    *   Deploy the container image to Cloud Run. This command creates a new Cloud Run service using the built image and configures it. We will also set the `GEMINI_API_KEY` as a secure environment variable for the Cloud Run service.
        ```bash
        gcloud run deploy project-pastra-dev-api \
          --image gcr.io/amitai-454317/project-pastra-dev-api \
          --platform managed \
          --region us-central1 \
          --allow-unauthenticated \
          --set-env-vars GEMINI_API_KEY='YOUR_GEMINI_API_KEY'
        ```
        **Notes:**
        *   Replace `'YOUR_GEMINI_API_KEY'` with your actual API key.
        *   `--platform managed` specifies the fully managed environment.
        *   `--region us-central1` is a suggested region; you can change this if desired.
        *   `--allow-unauthenticated` makes the service publicly accessible (suitable for this demo).
        *   `--set-env-vars GEMINI_API_KEY='YOUR_GEMINI_API_KEY'` securely sets the API key as an environment variable for the running service.
    *   Access the application: The `gcloud run deploy` command will output the URL of your deployed service. Open this URL in your web browser.
ARG BASE_IMAGE="artifactory.rr.ru/python-community-docker/python:3.11.10-slim-rbru"
ARG BUILD_ENVIRONMENT="local"

# 
# This stage is fit for GitLab CI.
# 
FROM ${BASE_IMAGE} AS deps-image-gitlab

ENV VENV_PATH="/srv/www/.venv"

COPY [".venv", "${VENV_PATH}"]

RUN find .venv/bin -type f -exec sed --in-place 's#\/[^.]*\.venv#/srv/www/.venv#g' {} + \
    && ln --symbolic --force /usr/local/bin/python .venv/bin/python
# # 
# # This stage is fit for local development.
# # 

FROM ${BASE_IMAGE} AS deps-image-local

COPY ["uv.lock", "pyproject.toml", "./"]

RUN export UV_INDEX_rr_USERNAME=$ARTIFACTORY_USER \
    export UV_INDEX_rr_PASSWORD=$ARTIFACTORY_PASSWORD \
    export UV_INDEX_DET_USERNAME=$ARTIFACTORY_USER \
    export UV_INDEX_DET_PASSWORD=$ARTIFACTORY_PASSWORD \
    uv sync
# 
# A switch between previous gitlab- and local- stages.
# Will be used in the `COPY --from` instriction of the `app-image` stage.
# 
FROM deps-image-${BUILD_ENVIRONMENT} as deps-image
# 
# An image containing our app.
# 
FROM ${BASE_IMAGE} as app-image

ENV REQUESTS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
ENV VENV_PATH="/srv/www/.venv"
ENV PATH="${VENV_PATH}/bin:${PATH}"
ENV HOME_PATH="/home/service"
ENV PYTHONUNBUFFERED=1

ENV OPENSEARCH_HOST=""
ENV OPENSEARCH_PORT=0
ENV OPENSEARCH_USER=""
ENV OPENSEARCH_PASS=""

RUN groupadd --gid 1000 \
    service \
    && useradd --uid 1000 \
    --gid service \
    --home ${HOME_PATH} \
    --create-home \
    --shell /bin/bash \
    service

WORKDIR ${HOME_PATH}

COPY --from=deps-image --chown=1000:1000 ${VENV_PATH} ${VENV_PATH}
COPY ["src", "./src"]
COPY ["docker/app.Dockerfile", \
    "logging.conf", \
    "uv.lock", \
    "pyproject.toml", \
    "./"]

RUN chown --recursive \
    service:service \
    ./

USER service

ENTRYPOINT ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--log-config", "logging.conf"]
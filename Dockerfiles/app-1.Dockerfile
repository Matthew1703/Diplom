ARG BASE_IMAGE="artifactory.rr.ru/python-community-docker/python:3.11.9-slim-rbru"
ARG BUILD_ENVIRONMENT="local"

FROM ${BASE_IMAGE} AS deps-image-gitlab

ENV VENV_PATH="/srv/www/.venv"

COPY [".venv", "${VENV_PATH}"]

RUN find .venv/bin -type f -exec sed --in-place 's#\/[^.]*\.venv#/srv/www/.venv#g' {} + \
    && ln --symbolic --force /usr/local/bin/python .venv/bin/python

FROM ${BASE_IMAGE} AS deps-image-local
RUN ls -R

COPY ["secrets/arti", "./"]
COPY ["poetry.lock", "pyproject.toml", "./"]

RUN --mount=type=secret,id=arti \
    poetry config http-basic.rr $(head -1 ./arti) $(tail -1 ./arti) && \
    poetry config http-basic.det $(head -1 ./arti) $(tail -1 ./arti) && \
    poetry config virtualenvs.in-project true && \
    poetry install --only main

FROM deps-image-${BUILD_ENVIRONMENT} as deps-image

FROM ${BASE_IMAGE} as app-image

ENV REQUESTS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
ENV VENV_PATH="/srv/www/.venv"
ENV PATH="${VENV_PATH}/bin:${PATH}"
ENV HOME_PATH="/home/service"

ENV POSTGRES_DSN=""

RUN groupadd --gid 1000 service \
    && useradd --uid 1000 --gid service --home ${HOME_PATH} --create-home --shell /bin/bash service

WORKDIR ${HOME_PATH}

RUN chown --recursive service:service ./

USER service

COPY --from=deps-image --chown=1000:1000 ${VENV_PATH} ${VENV_PATH}
COPY ["src", "./src"]
COPY ["logging.conf","./"]

ENTRYPOINT ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--log-config", "logging.conf"]
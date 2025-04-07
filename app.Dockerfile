# This Dockerfile contains four stages:
# - deps-image-gitlab
# - deps-image-local
# - deps-image
# - app-image
#
# The purpose of the `app-image` stage is to create the final image containing our app.
# This stage is the one that should be built by kaniko in the `build-app-image` step,
# and it is defined in `.gitlab-ci.yml` file via `--target app-image` flag.
#
# Both `deps-image-gitlab` and `deps-image-local` stages are destined to load and install all necessary dependencies -
# poetry dependencies in our case.
#
# In `deps-image-gitlab` we just copy the virtual environment `.venv` folder and mutate it in order to be consistent
# with the target container environment.
#
# In `deps-image-local` we read Artifactory credentials from `secrets/arti` file, which has the following structure:
#
# username
# password
#
# Therefore if we want to run this Dockerfile locally, we should create this `secrets/arti` file, placing `secrets` folder
# at the project root level.
#
# The purpose of the `deps-image` stage as long as the `BUILD_ENVIRONMENT` argument variable
# is to switch between `deps-image-gitlab` and `deps-image-local` stages while running the `app-image` stage,
# particularly the `COPY --from` instruction.
#
# So in order to run this Dockerfile locally, we should change the `BUILD_ENVIRONMENT` argument variable to "local".
# You can also see that this argument variable is set to 'gitlab' in the `build-app-image` step
# in `.gitlab-ci.yml`: `--build-arg BUILD_ENVIRONMENT=gitlab`, because there we want to use `deps-image-gitlab`
# inside the `COPY --from` instruction of the `app-image` stage.
#

ARG BASE_IMAGE="artifactory.raiffeisen.ru/python-community-docker/python:3.11.10-slim-rbru"
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
    poetry config http-basic.raif $(head -1 ./arti) $(tail -1 ./arti) && \
    poetry config http-basic.det $(head -1 ./arti) $(tail -1 ./arti) && \
    poetry config virtualenvs.in-project true && \
    poetry install --only main

FROM deps-image-${BUILD_ENVIRONMENT} as deps-image

FROM ${BASE_IMAGE} as app-image

ENV REQUESTS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
ENV VENV_PATH="/srv/www/.venv"
ENV PATH="${VENV_PATH}/bin:${PATH}"
ENV HOME_PATH="/home/cms-ripper"

ENV POSTGRES_DSN=""

RUN groupadd --gid 1000 cms-ripper \
    && useradd --uid 1000 --gid cms-ripper --home ${HOME_PATH} --create-home --shell /bin/bash cms-ripper

WORKDIR ${HOME_PATH}

RUN chown --recursive cms-ripper:cms-ripper ./

USER cms-ripper

COPY --from=deps-image --chown=1000:1000 ${VENV_PATH} ${VENV_PATH}
COPY ["src", "./src"]
COPY ["logging.conf","./"]

ENTRYPOINT ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--log-config", "logging.conf"]
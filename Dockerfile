FROM ruby:alpine

LABEL "com.github.actions.name"="Rubocop Linter for PRs"
LABEL "com.github.actions.description"="A GitHub Action that lints your Ruby PRs with Rubocop"
LABEL "com.github.actions.icon"="code"
LABEL "com.github.actions.color"="red"

LABEL "repository"="https://github.com/alexanderzagaynov/rubocop-action"
LABEL "maintainer"="Alexander Zagaynov <zalex80@gmail.com>"
LABEL "version"="0.0.1"

RUN set -ex \
 && apk update \
 && apk upgrade \
 && apk add \
      build-base \
      git \
 && gem install \
      rubocop \
      rubocop-rake \
      rubocop-rails \
      rubocop-rspec \
      rubocop-minitest \
      rubocop-performance \
      rubocop-sequel

WORKDIR /github/action
COPY lib .

ENTRYPOINT ["ruby", "rubocop.rb"]

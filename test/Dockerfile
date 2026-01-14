# open cmd in current folder knownuser-v3-ruby and run following commands
# docker build -f ./test/Dockerfile -t img-rails-tests-app .

FROM ruby:3.4

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      build-essential libpq-dev nodejs \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir /app
WORKDIR /app

COPY Gemfile queueit_knownuserv3.gemspec /app/
COPY lib/ /app/lib/
RUN bundle install

COPY . /app

RUN ruby ./test/test_queueit_knownuserv3.rb
FROM ruby:2.3

COPY Gemfile /usr/src/app/Gemfile
COPY Gemfile.lock /usr/src/app/Gemfile.lock
WORKDIR /usr/src/app
RUN bundle install --quiet

COPY . /usr/src/app
EXPOSE 4567
CMD bundle exec rackup -p 4567 --host 0.0.0.0

# Use the official lightweight Ruby image.
# https://hub.docker.com/_/ruby
FROM ruby:3.2.1

# Install bundler
RUN gem update --system
RUN gem install bundler

# Install production dependencies.
WORKDIR /usr/src/app
COPY Gemfile Gemfile.lock ./
RUN bundle install
ENV BUNDLE_FROZEN=true

# Copy local code to the container image.
COPY . ./

# Environment
ENV RAILS_ENV production
ENV RAILS_MAX_THREADS 60
ENV RAILS_LOG_TO_STDOUT true

# Run the web service on container startup.
CMD ["bundle", "exec", "rails", "s", "-p", "8080"]
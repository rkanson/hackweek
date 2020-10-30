FROM ruby:2.6.5

RUN gem install bundler jekyll
RUN echo "exclude: [vendor]" >> _config.yml
RUN bundle install
RUN bundle exec jekyll serve

EXPOSE 4000

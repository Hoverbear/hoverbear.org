all:
	bundle exec jekyll build

serve:
	bundle exec jekyll serve --host 0.0.0.0

install:
	bundle install

update:
	bundle update

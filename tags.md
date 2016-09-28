---
layout: page
title: "Tags"
---

{% assign sorted_tags = site.data.tags | sort %}

{% for tag in sorted_tags %}
  <h2 id="{{tag | downcase | slugify}}">{{ tag }}</h2>
  <ul>
    {% for post in site.posts %}
      {% if post.tags contains tag %}
        <li><a href="{{ post.url }}">{{ post.date | date_to_string }} - {{ post.title }}</a></li>
      {% endif %}
    {% endfor %}
  </ul>
{% endfor %}

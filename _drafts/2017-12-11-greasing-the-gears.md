---
layout: post
title: "Greasing the Gears"

image: /assets/images/2017/12/engine.jpg
image-credit: "@rktkn"

tags:
---

> It's been quite a journey so far, but there is still a long ways to go. We can't stop. We must triage, repair, and replace while the motor is still running. We can't do it alone, but together, with hard work, we might make it.

During my education, one of the most surprisingly interesting courses I took was **Software Evolution**. I originally took it because I know the professor was great, but it turned out to be hugely inspirational and motivating in the last years.

During that class we didn't study how to write code, how to write better code, or how to find bad code. We barely even talked about code at all. We talked about teams, pressure, time, and working together. It turned out, that software evolution was mostly not about the software itself, but instead it was about the people who wanted it to do things.

# Evolution Relativity

**Left alone**, forgotten in a closet, is in many ways the most stable a system can be. The sleepy log server that only ever complains when it runs out of disk space is probably the most reliable system in most clusters. Why? Management never brings feature requests for the log server. Noone ever gets a ticket "Add a new chat feature to the log server," unless you work at Google (😉). The system *evolves* at a very slow pace. Once in awhile someone might roll out a routine software update, but it's rare for those kinds of systems break down. 

At the same time, when those kinds of systems fail, they fail *hard* and they fail *fast*. The disk fails, and the team realizes they didn't have backups. No big loss, but it turns out when the log server is down some random worker is failing, and that's piling up billing jobs, customers can't pay, orders don't get processed. Someone gets called on the weekend to fix it. The log server is replaced, and a "new, better" system which noone really understands is installed, and it's left to fail again eventually.

**Constantly developed**, other systems evolve at a rapid page. New features are added, dependencies added or changed, components split apart, and even the occasional redesign occurs. They are systems in constant movement. 

# 

---

> If your data is a flock of sheep, then your code is the dogs (both good and bad), and your team members are the shepherds.

> My travels, education, career, and network of contacts affords me what I consider a reasonably wide glimpse into the practices of smaller development teams (<50).
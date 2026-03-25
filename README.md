# Admit N: Fulfill One-Off Payments by Adding Users to Access Control

In the process of creating the video-on-demand lectures for [the
Semantic REST training
seminar](https://methodandstructure.com/semantic-rest), I was
convinced that self-hosting would actually be a better plan than going
with a platform. I already have the bulk of the infrastructure in
place, except the one thing that was outstanding was something to take
paid customers and actually give them access to the content. I was
originally planning to just graft something onto [Forget
Passwords](https://github.com/doriantaylor/rb-forget-passwords), but
[reality has a surprising amount of
detail](https://senseatlas.net/82a04484-0bf1-48e7-8468-6c01be12e314).

# Design

The main thing [this
microservice](https://senseatlas.net/19b0ccd6-4602-4aa3-a51f-2149080111c8)
needs to do is deal with the outcome of a customer making a
purchase. All _that_ consists of is confirming the payment, then
enrolling one or more e-mail addresses into an access control
database. In the base case (where the customer bought a seat for
themselves), it should also forward the customer on to where they can
enjoy their purchase.

The catch, here, is one _or more_. One use case I want to be able to
handle is [a manager purchasing a block of audience
slots](https://senseatlas.net/e061cc87-2a85-45dc-bf31-0062fb12b9b2)
for their team. As such, there needs to be UI for the manager to
assign slots to e-mail addresses. The manager, furthermore, may not be
interested in the content for themselves, so I don't want to force
them to buy an extra seat just to manage the other seats they bought.

So there needs to be an "account manager" role distinct from the
"audience" who actually gets access to the content, but only as long
as there are open slots. There is nothing else for the account manager
to do once every slot is assigned (except perhaps buy more of them). I
do not want them to be able to reassign slots willy-nilly. If they
make a mistake; they can contact me to fix it. If a customer wants
more slots, they can pay for them.

The solution here, I think, is to present the customer ("account
manager") with a landing page with the number of slots they have
purchased, and the first slot has been auto-filled with their own
email address. Confirming this will take them to the content. They can
also leave slots empty and come back and fill them in later.

> To buy access as a gift for somebody, just buy one audience slot and
> when it redirects to the slot assignment/confirmation page, put
> their e-mail address in place of yours.

As far as explicit UI is concerned, then, this microservice only
consists of the one resource where the account manager role can
allocate empty slots. There also needs to be a webhook target for
receiving payment confirmation asynchronously from Stripe.

## Changes to Authentication/Authorization

This microservice will also be a client to [Forget
Passwords](https://github.com/doriantaylor/rb-forget-passwords), and
it will be necessary to modify the latter to be remotely operated.

* enroll user(s)
* add them to group(s)
* get a session cookie for a principal (auth bypass)

these just need to be

## Installation

You know how to do this:

    $ gem install admit-n

Or, [download it off rubygems.org](https://rubygems.org/gems/admit-n).

## Contributing

Bug reports and pull requests are welcome at
[the GitHub repository](https://github.com/doriantaylor/rb-admit-n).

## Copyright & License

©2026 [Dorian Taylor](https://doriantaylor.com/)

This software is provided under
the [Apache License, 2.0](https://www.apache.org/licenses/LICENSE-2.0).

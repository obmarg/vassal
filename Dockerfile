FROM elixir:1.5.2-alpine as builder

RUN apk add --update build-base
RUN mix local.hex --force && mix local.rebar --force

WORKDIR /tmp
RUN mkdir vassal
COPY mix.exs mix.lock /tmp/vassal/
COPY rel /tmp/vassal/rel/
COPY config /tmp/vassal/config/
COPY lib /tmp/vassal/lib/
COPY priv /tmp/vassal/priv/

# Get & compile things
WORKDIR /tmp/vassal

RUN mix deps.get
RUN mix deps.compile
RUN mix compile
RUN MIX_ENV=prod mix release --env=prod

FROM alpine:3.6

RUN apk add --update python openssl

RUN mkdir /app
COPY --from=builder /tmp/vassal/rel/vassal /app
WORKDIR /app
CMD [ "bin/vassal", "foreground" ]

EXPOSE 4567

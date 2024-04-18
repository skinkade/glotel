# glotel

[![Package Version](https://img.shields.io/hexpm/v/glotel)](https://hex.pm/packages/glotel)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glotel/)

```sh
gleam add glotel
```

Currently supports basic tracing functionality.

Documentation can be found at <https://hexdocs.pm/glotel>.

## Running an Application

Refer to the [OpenTelemetry environment
variables](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/)
for SDK configuration, e.g.:

```shell
export OTEL_SERVICE_NAME="your_application"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
export OTEL_EXPORTER_OTLP_HEADERS="x-service-api-key=12345"
gleam run
```

### Testing an Application

This command will launch a Jaeger instance for collecting traces during local
development on port 4318, with a web portal for viewing at
[http://localhost:16686/](http://localhost:16686/).

```shell
docker run --rm --name jaeger \
  -e COLLECTOR_ZIPKIN_HOST_PORT=:9411 \
  -p 6831:6831/udp \
  -p 6832:6832/udp \
  -p 5778:5778 \
  -p 16686:16686 \
  -p 4317:4317 \
  -p 4318:4318 \
  -p 14250:14250 \
  -p 14268:14268 \
  -p 14269:14269 \
  -p 9411:9411 \
  jaegertracing/all-in-one:1.56
```


## Known Quirks

There may be a warning on application startup that the OTLP exporter failed to
start, and then successfully starts, e.g.:

```
OTLP exporter failed to initialize with exception error:{badmatch,
                                                         {error,
                                                          inets_not_started}}
...
INFO OTLP exporter successfully initialized
```

## Basic Examples

```gleam
import glotel/span

pub fn foo() {
  use span_ctx <- span.new("span_name", [#("attribute", "value")])
  ...
}

pub fn bar_error() {
  use span_ctx <- span.new("span_name", [])
  span.set_error_message(span_ctx, "Descriptive error message")
  ...
}

pub fn baz_try_error() {
  use span_ctx <- span.new("span_name", [])
  use baz <- span.try_with_message(
    span_ctx,
    "Failed to baz",
    Error("Descriptive error message"),
  )
  ...
}
```

## Example Wisp Middleware

```gleam
import gleam/http.{method_to_string}
import gleam/int
import glotel/span
import glotel/span_kind
import wisp.{type Request, type Response}

pub fn trace_middleware(request: Request, handler: fn() -> Response) -> Response {
  let method = method_to_string(request.method)
  let path = request.path

  span.extract_values(request.headers)

  use span_ctx <- span.new_of_kind(span_kind.Server, method <> " " <> path, [
    #("http.method", method),
    #("http.route", path),
  ])

  let response = handler()

  span.set_attribute(
    span_ctx,
    "http.status_code",
    int.to_string(response.status),
  )

  case response.status >= 500 {
    True -> span.set_error(span_ctx)
    _ -> Nil
  }

  response
}
```


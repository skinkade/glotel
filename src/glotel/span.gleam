import gleam/dict.{type Dict}
import glotel/span_kind.{type SpanKind}
import glotel/span_status_code.{type SpanStatusCode}

type Application

@external(erlang, "application", "get_application")
fn get_application() -> Application

type Tracer

@external(erlang, "opentelemetry", "get_application_tracer")
fn get_application_tracer(application: Application) -> Tracer

/// An OpenTelemetry span context
/// 
pub type SpanContext

@external(erlang, "glotel_ffi", "do_start_span")
fn do_start_span(
  tracer: Tracer,
  name: String,
  kind: SpanKind,
  attributes: Dict(String, String),
) -> SpanContext

@external(erlang, "otel_span", "end_span")
fn do_end_span(span: SpanContext) -> Nil

type OtelContext

@external(erlang, "otel_ctx", "get_current")
fn current_otel_context() -> OtelContext

@external(erlang, "otel_tracer", "set_current_span")
fn set_current_span(context: OtelContext, span: SpanContext) -> OtelContext

type ContextToken

@external(erlang, "otel_ctx", "attach")
fn attach(context: OtelContext) -> ContextToken

@external(erlang, "otel_ctx", "detach")
fn detach(token: ContextToken) -> Nil

/// Creates a new span context, automatically linked to its immediate parent span, if present.
/// Default to a internal span kind.
/// 
/// ## Examples
/// 
/// ```gleam
/// fn foo() {
///     use span_ctx <- new("foo", [#("attribute", "value")])
/// }
/// ```
/// 
pub fn new(
  name: String,
  attributes: List(#(String, String)),
  apply: fn(SpanContext) -> a,
) -> a {
  new_of_kind(span_kind.Internal, name, attributes, apply)
}

/// Same as `new`, but allows specifying span kind.
/// 
/// ## Examples
/// 
/// ```gleam
/// fn server_foo() {
///   use span_ctx <- new_of_kind(span_kind.Server, "server_foo", [
///     #("attribute", "value"),
///   ])
/// }
/// ```
/// 
pub fn new_of_kind(
  kind: SpanKind,
  name: String,
  attributes: List(#(String, String)),
  apply: fn(SpanContext) -> a,
) -> a {
  let otel_context = current_otel_context()
  let application = get_application()
  let tracer = get_application_tracer(application)
  let span = do_start_span(tracer, name, kind, dict.from_list(attributes))
  let otel_context2 = set_current_span(otel_context, span)
  let token = attach(otel_context2)

  let result = apply(span)

  do_end_span(span)
  detach(token)

  result
}

/// Sets an additional attribute on a given span.
/// 
/// ## Examples
/// 
/// ```gleam
/// fn foo() {
///   use span_ctx <- new("foo", [])
///   set_attribute(span_ctx, "bar", "baz")
/// }
/// ```
/// 
@external(erlang, "otel_span", "set_attribute")
pub fn set_attribute(span: SpanContext, key: String, value: String) -> Nil

@external(erlang, "otel_span", "set_status")
fn do_set_status(span: SpanContext, status: SpanStatusCode) -> Nil

/// Sets `error = true` on a given span.
/// 
/// ## Examples
/// 
/// ```gleam
/// case status_code >= 500 {
///   True -> set_error(span_ctx)
///   False -> Nil
/// }
/// ```
/// 
pub fn set_error(span: SpanContext) -> Nil {
  do_set_status(span, span_status_code.Error)
}

@external(erlang, "otel_span", "set_status")
fn do_set_status_with_message(
  span: SpanContext,
  status: SpanStatusCode,
  message: String,
) -> Nil

/// Same as `set_error`, but allows specifying an explicit error message.
/// 
/// ## Examples
/// 
/// ```gleam
/// case status_code >= 500 {
///   True ->
///     set_error_message(
///       span_ctx,
///       "Request error: " <> int.to_string(status_code),
///     )
///   False -> Nil
/// }
/// ```
/// 
pub fn set_error_message(span: SpanContext, message: String) -> Nil {
  do_set_status_with_message(span, span_status_code.Error, message)
}

/// Same as standard library `result.try()`,
/// but automatically calls `set_error(span)` on an Error.
/// 
pub fn try(
  span: SpanContext,
  result: Result(a, e),
  apply fun: fn(a) -> Result(b, e),
) -> Result(b, e) {
  case result {
    Ok(x) -> fun(x)
    Error(e) -> {
      set_error(span)
      Error(e)
    }
  }
}

/// Same as standard library `result.try()`,
/// but automatically calls `set_error_message(span, message)` on an Error.
/// 
pub fn try_with_message(
  span: SpanContext,
  message: String,
  result: Result(a, e),
  apply fun: fn(a) -> Result(b, e),
) -> Result(b, e) {
  case result {
    Ok(x) -> fun(x)
    Error(e) -> {
      set_error_message(span, message)
      Error(e)
    }
  }
}

/// Extract OpenTelemetry attributes like `traceparent` from request headers.
/// 
/// ## Examples
/// 
/// ```gleam
/// pub fn trace_middleware(request: Request, handler: fn() -> Response) -> Response {
///   extract_values(request.headers)
/// }
/// ```
/// 
@external(erlang, "otel_propagator_text_map", "extract")
pub fn extract_values(values: List(#(String, String))) -> Nil

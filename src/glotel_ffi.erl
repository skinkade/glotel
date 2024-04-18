-module(glotel_ffi).

-export([do_start_span/4]).

do_start_span(Tracer, Name, Kind, Attributes) ->
    otel_tracer:start_span(Tracer, Name, #{kind => Kind, attributes => Attributes}).

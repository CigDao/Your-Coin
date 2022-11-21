export const idlFactory = ({ IDL }) => {
  const Holder = IDL.Record({ 'holder' : IDL.Text, 'amount' : IDL.Nat });
  const HeaderField = IDL.Tuple(IDL.Text, IDL.Text);
  const Request = IDL.Record({
    'url' : IDL.Text,
    'method' : IDL.Text,
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HeaderField),
  });
  const StreamingCallbackToken = IDL.Record({
    'key' : IDL.Nat32,
    'sha256' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'index' : IDL.Nat32,
    'content_encoding' : IDL.Text,
  });
  const StreamingCallbackResponse = IDL.Record({
    'token' : IDL.Opt(StreamingCallbackToken),
    'body' : IDL.Vec(IDL.Nat8),
  });
  const StreamingCallback = IDL.Func(
      [StreamingCallbackToken],
      [StreamingCallbackResponse],
      ['query'],
    );
  const StreamingStrategy = IDL.Variant({
    'Callback' : IDL.Record({
      'token' : StreamingCallbackToken,
      'callback' : StreamingCallback,
    }),
  });
  const Response = IDL.Record({
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HeaderField),
    'streaming_strategy' : IDL.Opt(StreamingStrategy),
    'status_code' : IDL.Nat16,
  });
  return IDL.Service({
    'burnFee' : IDL.Func([IDL.Float64], [], []),
    'distribute' : IDL.Func([IDL.Nat, IDL.Vec(Holder)], [], []),
    'http_request' : IDL.Func([Request], [Response], ['query']),
    'marketingFee' : IDL.Func([IDL.Float64], [], []),
    'treasuryFee' : IDL.Func([IDL.Float64], [], []),
    'updateBurnPercentage' : IDL.Func([IDL.Float64], [], []),
    'updateMarketingPercentage' : IDL.Func([IDL.Float64], [], []),
    'updateReflectionPercentage' : IDL.Func([IDL.Float64], [], []),
    'updateTreasuryPercentage' : IDL.Func([IDL.Float64], [], []),
  });
};
export const init = ({ IDL }) => { return []; };

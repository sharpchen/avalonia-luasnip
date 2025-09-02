local ls = require('luasnip')
local snip = ls.snippet --[[@as fun(trigger: string | { trig: string, name: string, desc: string }, node: any[] | any)]]
local ins = ls.insert_node --[[@as fun(idx: integer, placeholder: string)]]
local fn = ls.function_node
local fmt = require('luasnip.extras.fmt').fmt --[[@as fun(body: string, nodes: any[] | any, opts?: table)]]
local rep = require('luasnip.extras').rep --[[@as fun(idx: integer)]]
local oneof = ls.choice_node
local text = ls.text_node
local dyn = ls.dynamic_node
local sn = ls.snippet_node

---@return { classname: string, modifiers: string[] }?
local function classinfo()
  local cursor_node = vim.treesitter.get_node { ignore_injections = false }
  if not cursor_node then return nil end

  local parent = cursor_node:parent()
  while parent and parent:type() ~= 'class_declaration' do
    parent = parent:parent()
  end

  if not parent then return nil end

  local classname
  local modifiers = {}
  local query = vim.treesitter.query.parse(
    'c_sharp',
    [[
      (class_declaration
      (modifier)* @modifiers
      name: (identifier) @class_name)
      ]]
  )

  for id, capture in query:iter_captures(parent, 0) do
    if query.captures[id] == 'class_name' then
      classname = vim.treesitter.get_node_text(capture, 0)
    end
    if query.captures[id] == 'modifiers' then
      table.insert(modifiers, vim.treesitter.get_node_text(capture, 0))
    end
  end

  return { classname = classname, modifiers = modifiers }
end

local function pascal2camel(name)
  local words = {}
  for word in name:gmatch('%u%l+') do
    table.insert(words, word)
  end
  local is_pascal = table.concat(words):len() == name:len()
  if is_pascal then
    local first = words[1]
    return first:lower() .. table.concat(vim.list_slice(words, 2))
  else
    return name
  end
end

return {
  snip(
    'directProperty',
    fmt(
      [[
    private {TValue} _{};

    public static readonly DirectProperty<{TOwner}, {TValue}> {}Property = AvaloniaProperty.RegisterDirect<{TOwner}, {TValue}>(
        nameof({}), o => o.{}, (o, v) => o.{} = v);

    public {TValue} {}
    {{
        get => _{};
        set => SetAndRaise({}Property, ref _{}, value);
    }}
      ]],
      {
        TValue = ins(2, 'TValue'),
        TOwner = fn(function() return classinfo().classname or 'TOwner' end),
        fn(function(args) return pascal2camel(args[1][1] or '') end, { 1 }),
        ins(1, 'PropertyName'),
        rep(1),
        rep(1),
        rep(1),
        rep(1),
        fn(function(args) return pascal2camel(args[1][1] or '') end, { 1 }),
        rep(1),
        fn(function(args) return pascal2camel(args[1][1] or '') end, { 1 }),
      },
      { repeat_duplicates = true }
    )
  ),
  snip(
    'styledProperty',
    fmt(
      [[
    public static readonly StyledProperty<{TValue}> {propertyName}Property = AvaloniaProperty.Register<{TOwner}, {TValue}>(
        nameof({propertyName}));

    public {TValue} {propertyName}
    {{
        get => GetValue({propertyName}Property);
        set => SetValue({propertyName}Property, value);
    }}
  ]],
      {
        propertyName = ins(1, 'propertyName'),
        TValue = ins(2, 'TValue'),
        TOwner = fn(function() return classinfo().classname or 'TOwner' end),
      },
      { repeat_duplicates = true }
    )
  ),
  snip(
    'attachedProperty',
    dyn(1, function()
      if vim.list_contains(classinfo().modifiers, 'static') then
        return sn(
          nil,
          fmt(
            [[
            public static readonly AttachedProperty<{TValue}> {propertyName}Property =
                AvaloniaProperty.RegisterAttached<{THost}, {TValue}>("{propertyName}", typeof({TOwner}));

            public static void Set{propertyName}({THost} host, {TValue} value) => host.SetValue({propertyName}Property, value);
            public static {TValue} Get{propertyName}({THost} host) => host.GetValue({propertyName}Property);
            ]],
            {
              propertyName = ins(1, 'propertyName'),
              TValue = ins(2, 'TValue'),
              TOwner = fn(function() return classinfo().classname or 'TOwner' end),
              THost = ins(3, 'THost'),
            },
            {
              repeat_duplicates = true,
            }
          )
        )
      else
        return sn(
          nil,
          fmt(
            [[
            public static readonly AttachedProperty<{TValue}> {propertyName}Property =
                AvaloniaProperty.RegisterAttached<{TOwner}, {THost}, {TValue}>("{propertyName}");

            public static void Set{propertyName}({THost} host, {TValue} value) => host.SetValue({propertyName}Property, value);
            public static {TValue} Get{propertyName}({THost} host) => host.GetValue({propertyName}Property);
            ]],
            {
              propertyName = ins(1, 'propertyName'),
              TValue = ins(2, 'TValue'),
              TOwner = fn(function() return classinfo().classname or 'TOwner' end),
              THost = ins(3, 'THost'),
            },
            {
              repeat_duplicates = true,
            }
          )
        )
      end
    end)
  ),
  snip(
    'routedEvent',
    fmt(
      [[
    public static readonly RoutedEvent<RoutedEventArgs> {eventName}Event =
        RoutedEvent.Register<{TOwner}, RoutedEventArgs>(nameof({eventName}), RoutingStrategies.{strategy});

    public event EventHandler<RoutedEventArgs> {eventName}
    {{
        add => AddHandler({eventName}Event, value);
        remove => RemoveHandler({eventName}Event, value);
    }}

    protected virtual void On{eventName}()
    {{
        RoutedEventArgs args = new RoutedEventArgs({eventName}Event);
        RaiseEvent(args);
    }}
  ]],
      {
        eventName = ins(1, 'eventName'),
        strategy = oneof(2, { text('Direct'), text('Tunnel'), text('Bubble') }),
        TOwner = fn(function() return classinfo().classname or 'TOwner' end),
      },
      { repeat_duplicates = true }
    )
  ),
}

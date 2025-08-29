local ls = require('luasnip')
local snip = ls.snippet --[[@as fun(trigger: string | { trig: string, name: string, desc: string }, node: any[] | any)]]
local ins = ls.insert_node --[[@as fun(idx: integer, placeholder: string)]]
local fn = ls.function_node
local fmt = require('luasnip.extras.fmt').fmt --[[@as fun(body: string, nodes: any[] | any, opts?: table)]]
local rep = require('luasnip.extras').rep --[[@as fun(idx: integer)]]
local oneof = ls.choice_node
local text = ls.text_node

local function classname()
  local cursor_node = vim.treesitter.get_node { ignore_injections = false }
  if not cursor_node then return nil end

  local parent = cursor_node:parent()
  while parent and parent:type() ~= 'class_declaration' do
    parent = parent:parent()
  end

  if not parent then return nil end

  local query = vim.treesitter.query.parse(
    'c_sharp',
    [[
  (class_declaration
    name: (identifier) @class_name)
  ]]
  )
  for _, capture in query:iter_captures(parent, 0) do
    return vim.treesitter.get_node_text(capture, 0)
  end
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
    private {propertyType} _{};

    public static readonly DirectProperty<{controlType}, {propertyType}> {}Property = AvaloniaProperty.RegisterDirect<{controlType}, {propertyType}>(
        nameof({}), o => o.{}, (o, v) => o.{} = v);

    public {propertyType} {}
    {{
        get => _{};
        set => SetAndRaise({}Property, ref _{}, value);
    }}
      ]],
      {
        propertyType = ins(2, 'propertyType'),
        controlType = fn(function() return classname() or 'controlType' end),
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
    public static readonly StyledProperty<{propertyType}> {propertyName}Property = AvaloniaProperty.Register<{controlType}, {propertyType}>(
        nameof({propertyName}));

    public {propertyType} {propertyName}
    {{
        get => GetValue({propertyName}Property);
        set => SetValue({propertyName}Property, value);
    }}
  ]],
      {
        propertyName = ins(1, 'propertyName'),
        propertyType = ins(2, 'propertyType'),
        controlType = fn(function() return classname() or 'controlType' end),
      },
      { repeat_duplicates = true }
    )
  ),
  snip(
    'attachedProperty',
    fmt(
      [[
    public static readonly AttachedProperty<{propertyType}> {propertyName}Property =
      AvaloniaProperty.RegisterAttached<{controlType}, {targetType}, {propertyType}>("{propertyName}");

    public static void Set{propertyName}({targetType} obj, {propertyType} value) => obj.SetValue({propertyName}Property, value);
    public static {propertyType} Get{propertyName}({targetType} obj) => obj.GetValue({propertyName}Property);
  ]],
      {
        propertyName = ins(1, 'propertyName'),
        propertyType = ins(2, 'propertyType'),
        controlType = fn(function() return classname() or 'controlType' end),
        targetType = ins(3, 'targetType'),
      },
      {
        repeat_duplicates = true,
      }
    )
  ),
  snip(
    'routedEvent',
    fmt(
      [[
    public static readonly RoutedEvent<RoutedEventArgs> {eventName}Event =
        RoutedEvent.Register<{controlType}, RoutedEventArgs>(nameof({eventName}), RoutingStrategies.{strategy});

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
        controlType = fn(function() return classname() or 'controlType' end),
      },
      { repeat_duplicates = true }
    )
  ),
}

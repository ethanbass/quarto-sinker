local groups = {}
local to_move = {}
local found = {}

local breaks = {
  docx = pandoc.RawBlock("openxml", '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'),
  latex = pandoc.RawBlock("latex", "\\clearpage"),
  typst = pandoc.RawBlock("typst", "#pagebreak()"),
  html = pandoc.RawBlock("html", '<div style="break-after: page;"></div>'),
}

local function pagebreak()
  for fmt, b in pairs(breaks) do
    if quarto.doc.is_format(fmt) then return b end
  end
end

local function marker(label)
  local ref = pandoc.Cite({ pandoc.Str("@" .. label) }, { pandoc.Citation(label, "NormalCitation") })
  return pandoc.Para({ pandoc.Str("["), ref, pandoc.Space(), pandoc.Str("about"), pandoc.Space(), pandoc.Str("here]") })
end

local function meta(m)
  local cfg = m["sinker"]
  if not cfg then return end
  if cfg.kinds then cfg = { cfg } end
  for i, g in ipairs(cfg) do
    local kinds = {}
    for _, k in ipairs(g.kinds or {}) do kinds[pandoc.utils.stringify(k)] = true end
    groups[i] = {
      kinds = kinds,
      target = g.to and pandoc.utils.stringify(g.to),
      pagebreak = g.pagebreak == true,
      markers = g.markers == true,
    }
  end
end

local function float(f)
  if f.parent_id ~= nil then return end
  local kind = f.identifier:match("^(.-)%-")
  for i, g in ipairs(groups) do
    if g.kinds[kind] then
      to_move[f.__quarto_custom_node.attributes.__quarto_custom_id] = { group = i, label = f.identifier }
      return
    end
  end
end

-- Quarto keeps each float as a Div tagged with __quarto_custom_id (internal, checked on 1.7)
local function marked(b)
  local m = b.attributes and to_move[b.attributes.__quarto_custom_id]
  if m then
    found[m.label] = true
    b:walk { Div = function(d)
      local sub = to_move[d.attributes.__quarto_custom_id]
      if sub then found[sub.label] = true end
    end }
    return m
  end
  if b.t == "Div" and (b.classes:includes("cell") or b.classes:includes("cell-output-display")
      or b.classes:includes("landscape")) then
    for _, c in ipairs(b.content) do
      local hit = marked(c)
      if hit then return hit end
    end
  end
end

local function move(doc)
  local keep, moved, at = pandoc.Blocks{}, {}, {}
  for _, b in ipairs(doc.blocks) do
    local m = marked(b)
    local g = m and m.group
    if g and not at[groups[g].target] then
      if groups[g].markers then keep:insert(marker(m.label)) end
      moved[g] = moved[g] or pandoc.Blocks{}
      moved[g]:insert(b)
      local br = groups[g].pagebreak and pagebreak()
      if br then moved[g]:insert(br) end
    else
      keep:insert(b)
      if b.t == "Header" and not at[b.identifier] then at[b.identifier] = #keep end
    end
  end
  for _, m in pairs(to_move) do
    if not found[m.label] then
      quarto.log.warning("sinker: left " .. m.label .. " in place because it is nested inside another block")
    end
  end
  local out = pandoc.Blocks{}
  for i, b in ipairs(keep) do
    out:insert(b)
    for g, grp in ipairs(groups) do
      if moved[g] and at[grp.target] == i then out:extend(moved[g]) end
    end
  end
  for g, grp in ipairs(groups) do
    if moved[g] and not at[grp.target] then out:extend(moved[g]) end
  end
  doc.blocks = out
  return doc
end

return {
  { Meta = meta },
  { FloatRefTarget = float },
  { Pandoc = move },
}

kpse.set_program_name "luatex"
local zip = require "zip"
local dom = require "luaxml-domobject"
local function odtfile(filename)
  local ODT = {}
  local zipfile, errmsg = zip.open(filename, "r")
  if not zipfile then return nil, errmsg end
  ODT.filename = filename
  local schemas = {}
  ODT.zipfile = zipfile
  local contentfile = zipfile:open "content.xml"
  local content = contentfile:read("*all")
  contentfile:close()
  local contentdom = dom.parse(content)
  local used_attrs = {}
  local used_elements = {}

  contentdom:traverse_elements(function(el)
    local name = el:get_element_name()
    local element = used_elements[name]
    if not element then
      element = {}
      local ns, newname = name:match("(.+):(.+)") 
      element.name = newname
      element.ns = ns
      used_elements[name] = element
    end
    el._name = element.name
    el._ns = element.ns

    print(name, element.name, element.ns)
    for attr, value in pairs(el._attr or {}) do
      if not used_attrs[attr] then
        local schema = attr:match "xmlns:(.+)"
        if schema then
          schemas[schema] = value
        end
      end
      used_attrs[attr] = true
    end
  end)
  ODT.schemas = schemas
  contentdom:serialize()
  -- print(content)
end

odtfile("sample.odt")
